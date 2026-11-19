# Table of Contents Generator

This script generates a table of contents for Github flavored Markdown documents. 

The script generates the table of contents between two HTML comments marking the TOC start and TOC end. When running the script for the first time on a file, use the `-a` option to add the TOC markers. They are added at the top of the file, after the YAML front matter if there is any.

The table of contents can either be generated as a section in the document, or as a collapsible section that defaults to a closed table. Use the `-c` option to generate a collapsed ToC.

This utility will only modify the markdown file if the table of contents generated is different than what already exists in the file, that is, when the headings or the ToC style (`-c` or not) have changed.

## Usage

```
toc [OPTION]... MARKDOWN-FILE

   -h                Usage information
   -c                Wrap the ToC with a collapsible <details> element
   -a                Add a ToC section to the file if it is missing
   -p                Print to stdout, don't update the file
   -f                Force an update, even if the ToC hash is correct
```

The markers must each be on a line of their own:

```
<!-- TOC START -->
<!-- TOC END -->
```

## What counts as a heading

* ATX headings (`# Title`, `## Title ##`) and setext headings (a line underlined with `===` or `---`).
* Headings inside fenced code blocks (```` ``` ```` or `~~~`), indented code blocks and YAML front matter are ignored.
* Links in headings are replaced with their text, and anchors follow GitHub's rules, including the `-1`, `-2` suffixes for duplicate headings.

## Requirements

* `bash`, `gawk`, `openssl`, `mktemp`, `date` and `cat`.
* On macOS, install GNU awk with `brew install gawk`.

## Example


Given the following markdown document:

```
# First Section

## First Sub Section

## Second Sub Section

# Second Section

## First Sub Section

```

The following will be generated:

<hr>

Table of Contents
=================

  * [First Section](#first-section)
    * [First Sub Section](#first-sub-section)
    * [Second Sub Section](#second-sub-section)
  * [Second Section](#second-section)
    * [First Sub Section](#first-sub-section-1)
<hr>

If the `-c` option is specified, then the following will be generated:

<hr>
<details>
  <summary>Table of Contents</summary>

  * [First Section](#first-section)
    * [First Sub Section](#first-sub-section)
    * [Second Sub Section](#second-sub-section)
  * [Second Section](#second-section)
    * [First Sub Section](#first-sub-section-1)

</details>
<hr>

## Tests

Run `tests/run-tests.sh`. It exits with a non-zero status if any test fails.
