# Table of Contents Generator

This script generates a table of contents for Github flavored Markdown documents. 

The script generates the table of contents between two HTML comments marking the TOC start and TOC end. When running the script for the first time on a file, use the `-a` option to add the TOC markers. 

The table of contents can either be generated as a section in the document, or as a collapsible section that defaults to a closed table. Use the `-c` option to generate a collapsed ToC.

This utility will only modify the markdown file if the table of contents generated is different than what already exists in the file.

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

  * [First Section](#)
    * [First Sub Section](#)
    * [Second Sub Section](#)
  * [Second Section](#)
    * [First Sub Section](#)
<hr>

If the `-c` option is specified, then the following will be generated:

<hr>
<details>
  <summary>Table of Contents</summary>

  * [First Section](#)
    * [First Sub Section](#)
    * [Second Sub Section](#)
  * [Second Section](#)
    * [First Sub Section](#)

</details>
<hr>
