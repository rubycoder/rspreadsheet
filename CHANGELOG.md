# Changelog

## 0.5.4

- Support `libxml-ruby` 6 while retaining the legacy require path fallback.
- Support reading and writing OpenDocument boolean cells.
- Support the `rubyzip` 3 API and rebuild modified ODS archives atomically,
  addressing upstream issues [#67](https://github.com/gorn/rspreadsheet/issues/67)
  and [#68](https://github.com/gorn/rspreadsheet/issues/68).
- Retain the formatted-empty-row fix contributed by Jennifer Glauche in
  upstream pull request [#52](https://github.com/gorn/rspreadsheet/pull/52).
- Include the GUIDE formatting contribution by Tomasz Szymczyszyn from
  upstream pull request [#56](https://github.com/gorn/rspreadsheet/pull/56).

Earlier releases are documented in the
[upstream release history](https://github.com/gorn/rspreadsheet/releases).
