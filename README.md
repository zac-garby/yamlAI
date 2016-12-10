# yamlAI
A tool for making chatbots using Ruby and YAML.

## Example
```yaml
data:
  name: "Bot"
  person: "Human"
rules:
  "hi *|hello *|hey *|howdy *": "Hello, @person."
  "what is your name *": "My name is @name"
  "i am called !0 * | my name is !0 *": ":person=0: Okay, @person, I will now call you ?0%!|.%"
  "__unknown": "%What|Huh|What do you mean%?"
```
I'll explain the details later, but here's an example session with this AI:
```
1.  You> Hello world
2.  AI> Hello, Human.
3.  You> What is your name?
4.  AI> My name is Bot
5.  You> My name is Zac
6.  AI> Okay, Human, I will now call you zac.
7.  You> Hello
8.  AI> Hello, zac.
9.  You> goodbye
10. AI> Goodbye
  # The program exits.
```
I added the line numbers in myself.

On line 1, when I say "Hi", it searches through the rules defined in the YAML. First, it checks the rule defined as
`hello *|hi *|hey *|howdy *`. It splits the rule up into 4 other rules: `hello *`, `hi *`, `hey *` and `howdy *` and
checks each of them against the input text, `Hello world`. It checks `hi *`, which obviously doesn't match; it then checks
"hello *", which does match because `hello` matches `Hello` (case-insensitive) and the asterisk matches anything, so it
matches `world`. Because `Hello world` matches "hello *", it outputs the string to the right of the definition:
"Hello, @person.". The @person evaluates to `"Human"`, because in the data section of the YAML, 'person' is initialized to
`"Human"`.

The same kind of thing happens for the rest of the inputs.

## Syntax
When defining a rule, like `"what is your name *"` above, the following syntax applies:

 - `!0-9` - Matches anything once and saves whatever it matches into the numbered variable from 0 to 9
 - `x|y` - Creates subrules x and y, and matches either
 - `*` - Matches anything until the next definition token matches the next input token
 - `.` - Matches anything once

In outputs, this is the syntax:

 - `?0-9` - Loads the variable defined in the rule declaration
 - `%x|y|z%` - Chooses randomly between 'x', 'y' and 'z'
 - `:x=0:` - Sets data field 'x' to variable 0
 - `::x=hello::` - Sets data field 'x' to string 'hello'
 - `@x` - Loads the data field named 'x'
 - `{func arg}` - Calls the function 'func' defined in _functions.rb_ and passes it the argument, the rule variables, and the AI's data dictionary

## Getting Started
If you want to just quickly run a chatbot, download the entire repo and run the following commands in Terminal (This is UNIX, however it's probably very similar on Windows):

Firstly, though, you will need to install _colorize_, which is used for colouring output text, with the following command:
```
sudo gem install colorize
```
Leave off `sudo` if you're on Windows.

```
cd yamlAI
./main.rb
```
This should display open a prompt asking for your input.

If you want to make your own chatbot, read the example and syntax sections of this page and try and figure it out from that, or wait for me to make a GitHub Wiki page.
 
## TODO
In no order:

 - Allow calling functions in rule definitions
