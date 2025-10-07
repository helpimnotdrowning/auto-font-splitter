#!/usr/bin/pwsh
param (
	[String] $Source,
	[String] $OutputDirectory,
	[String] $CssFontPath
)

$OldErr = $ErrorActionPreference
$OldNativeErr = $PSNativeCommandUseErrorActionPreference

trap {
	$ErrorActionPreference = $OldErr
	$PSNativeCommandUseErrorActionPreference = $OldNativeErr
}

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if (
	[String]::IsNullOrWhiteSpace($Source) `
	-or [String]::IsNullOrWhiteSpace($OutputDirectory) `
	-or [String]::IsNullOrWhiteSpace($CssFontPath) `
) {
	Write-Host @'
Usage:

split -Source [file or directory] -OutputDirectory [directory] -CssFontPath [format string]

`-Source` is either a woff2 file or a directory of woff2 files
`-OutputDirectory` is the destination of the generated files
`-CssFontPath` is the file path used in the generated CSS file of where the font will be accesed from
	Write `<XX>` and it will be replaced with the font's name.
'@
	throw "-Source [file or directory], -OutputDirectory [directory], and -CssFontPath [string] parameters are all required!"
	exit
}

if (!(Test-Path -PathType Container $OutputDirectory)) {
	mkdir $OutputDirectory
}

if (Test-Path -PathType Leaf $Source) {
	$Files = @($Source)
} elseif (Test-Path -PathType Container $Source) {
	$Files = gci $Source *.woff2
}

# via https://skia.googlesource.com/skia/+/refs/heads/main/src/ports/SkFontMgr_fontconfig.cpp#324
# and https://api.skia.org/SkFontStyle_8h_source.html
# translate weight from fontconfig to corresponding CSS weight
$Fontconfig_to_CSS = @{
	0   = 100  # thin
	40  = 200  # extralight, ultralight
	50  = 300  # light
	55  = 350  # demilight, semilight
	75  = 380  # book
	80  = 400  # regular, normal
	100 = 500  # medium
	180 = 600  # demibold, semibold
	200 = 700  # bold
	205 = 800  # extrabold, ultrabold
	210 = 900  # black,heavy
	215 = 1000 # extrablack, ultrablack
}

$Files | % {
	$ErrorActionPreference = 'Stop'
	$PSNativeCommandUseErrorActionPreference = 'Stop'
	
	$Name = $_.BaseName
	$Output = "$OutputDirectory/$Name"
	$NewCss = "$Output/new.css"
	
	$FCWeight = [int] (fc-scan $_ -f '%{weight}')
	$CssWeight = $Fontconfig_to_CSS[$FCWeight]
	
	$You = "$(id -u):$(id -g)"
	mkdir $Output # OutputDirectory/font_name, we won't overwrite it
	sudo docker run --rm `
		-it `
		-v ./src:/fonts `
		-v "$Output`:/tmp/out" `
		-u $You `
		helpimnotdrowning/font-splitter `
			$_.Name `
			--output /tmp/out/ `
			--chunk 128 `
			--batches ((nproc) - 2) `
			--weight $CssWeight
	$StartCss = (gi $Output/*.css | Select-Object -First 1)
	
	# order the files by lastmodified by their appearence order
	grep -Po '(?<=url\().*?\)' $StartCss | % replace ')' '' | % {
		touch $Output/$_; sleep 0.05
	}
	$i=1
	gci $Output *.woff2 | Sort-Object -Prop LastWriteTime | % {
		"$i $($_.Name)"; $i++
	} > $Output/list
	touch $NewCss
	
	$FontPath = $CssFontPath.Replace('<XX>', $StartCss.BaseName)
	$i=1
	cat $StartCss | % {
		$Line = $_
		$PSNativeCommandUseErrorActionPreference = $false
		$OldName=($line | grep -Po '(?<=url\().*?\)' | % replace ')' '')
		$PSNativeCommandUseErrorActionPreference = $true
		if (![String]::IsNullOrWhiteSpace($OldName)) {
			$NewName = "{0:d3}.woff2" -f $i
			ren "$Output/$OldName" $NewName
			$Line.Replace($OldName, (Join-Path $FontPath ([Web.HttpUtility]::UrlEncode($NewName)))) >> $NewCss ; $i++
		} else {
			$Line >> $NewCss
		}
	}
	
	# gnu sed has no perl extension...
	# compress unicode ranges
	<#
	(?<= -- lookbehind to test for correct property
		unicode-range: U\+
		-- {1,230} is used instead of just + since perl doesn't implement
		   lookbehinds longer than 255 chars...
		[0-9a-f]{1,230}
	)
	-- characer after 1st codepoint can be a - (a range) / , (another codepoint)
	[-,].*?
	(?=
		-- but lookaheads are fine!
		[0-9a-f]+;
	)
	#>
	perl -pi -e 's#(?<=unicode-range: U\+[0-9a-f]{1,230})[-,].*?(?=[0-9a-f]{1,230};)#-#g' $NewCss
	
	rm $StartCss
	ren $NewCss $StartCss.Name
}

