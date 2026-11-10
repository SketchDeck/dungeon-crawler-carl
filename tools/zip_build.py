"""Zips a web export folder with index.html at the top level (what itch.io expects).

Usage: python3 tools/zip_build.py <export_dir> <zip_path>
"""
import os
import sys
import zipfile

src, dest = sys.argv[1], sys.argv[2]
if not os.path.isfile(os.path.join(src, "index.html")):
    sys.exit("No index.html in %s - did the export fail?" % src)
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(src)):
        path = os.path.join(src, name)
        if os.path.isfile(path):
            z.write(path, name)
size = os.path.getsize(dest) / 1e6
print("wrote %s (%.1f MB) - upload this to itch.io" % (dest, size))
