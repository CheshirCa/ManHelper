# SQLite amalgamation

This directory contains the SQLite 3.53.4 amalgamation (`sqlite3.c` and
`sqlite3.h`) downloaded from the official SQLite site:

https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip

`sqlite3.c` SHA-256:

```text
b1dd5d74ec7f29055a6684fa06fb3c2f6821c87dd38f9a458dfd2e8a1db28189
```

The build script compiles it as a static x64 library with FTS5 enabled. Generated
`.obj` and `.lib` files are not source-controlled.

SQLite is in the public domain. See:

https://www.sqlite.org/copyright.html
