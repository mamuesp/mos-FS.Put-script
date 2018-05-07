# mos-FS.Put-script

Reads a single file, encodes it in base64 and transfers it via "mos call FS.Put"
(RPC) to the Mongoose-OS driven device The lines are transferred one by one,
so there is no problem with any chunk size limits. If a directory name is given as
source, it will transfer all allowed files found in the driectory.

Allowed file types: (MIME)
- application/x-gzip
- text/html
- text/plain
- text/css
- text/javascript

## Usage: mosPutFile.sh --src=\<name\> --dest=\<name\> [--p=<port>] [--verbose]
  
Publisehd under the MIT license.
