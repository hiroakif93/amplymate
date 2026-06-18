INPUT=$1
OUT_PATH="DEMUX"

bcl-convert --bcl-input-directory . \
  --output-directory "./${OUT_PATH}" \
  --no-lane-splitting true \
  --force
