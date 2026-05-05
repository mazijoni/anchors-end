# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6

---

## Text Formatting

**Bold text**
*Italic text*
***Bold and italic***
~~Strikethrough~~
Normal text with a `inline code` span.

---

## Lists

### Unordered
- Item one
- Item two
  - Nested item
  - Another nested
    - Deeply nested

### Ordered
1. First
2. Second
   1. Sub-item
   2. Sub-item
3. Third

### Task List
- [x] Completed task
- [ ] Incomplete task
- [x] Another done

---

## Links & Images

[Visible link text](https://example.com)
[Link with title](https://example.com "Hover title")

![Alt text for image](https://via.placeholder.com/150 "Optional image title")

---

## Blockquote

> Single line quote.

> Multi-line quote.
> Second line of same quote.

> Nested quote
>> Indented deeper

---

## Code

Inline: `const x = 42;`

Fenced block (JavaScript):
```js
function greet(name) {
  return `hello, ${name}`;
}
```

Fenced block (Rust):
```rust
fn main() {
    println!("hello from MAZE");
}
```

Indented code block (4 spaces):

    this is an indented code block
    old-school markdown style

---

## Tables

| Name       | Type     | Status   |
|------------|----------|----------|
| Godot      | Engine   | Active   |
| Three.js   | Library  | Active   |
| Rust       | Language | Learning |

### Aligned columns

| Left align | Center align | Right align |
|:-----------|:------------:|------------:|
| A          |      B       |           C |
| foo        |     bar      |         baz |

---

## Horizontal Rules

Using dashes:

---

Using asterisks:

***

Using underscores:

___

---

## Footnotes

Here is a sentence with a footnote.[^1]

Another sentence with a second footnote.[^note]

[^1]: This is the first footnote.
[^note]: This is a named footnote.

---

## Definition List (extended MD)

Term
: Definition of the term.

Another Term
: First definition.
: Second definition.

---

## Abbreviations (extended MD)

This document uses MD syntax throughout.

*[MD]: Markdown

---

## Escape Characters

\*not italic\*
\`not code\`
\# not a heading
\[not a link\]

---

## Emoji (GitHub Flavored)

:rocket: :fire: :white_check_mark: :warning:

---

## HTML Inline (raw)

<kbd>Ctrl</kbd> + <kbd>S</kbd>

<mark>Highlighted text</mark>

<details>
<summary>Click to expand</summary>

Hidden content inside a details block.

</details>

---

## Math (extended — KaTeX/MathJax)

Inline: $E = mc^2$

Block:
$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$

---

*maze_joni · MAZE_Development · 2026*