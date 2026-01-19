---
title: Shortcuts
order: 5
---

# Git Shortcuts

## What are shortcuts?

A Git shortcut is a set of Git commands combined into a single script. It allows you to execute several sequential commands with a single click, greatly simplifying your work.
  
Let's say you're working on a task and, once finished, want to switch to the next one, or maybe you've already switched but haven't yet managed to switch branches.
The sequence of actions would then be something like this: stash -> switch branch to master -> fetch -> pull -> create new branch -> push new branch -> apply stash.
That's a lot of steps, and each one takes a few seconds to complete.
With Git shortcuts, you no longer need to worry about this.
  
## Create first shortcut

Click **Add Shortcut**. A creation window will open.

![shortcuts](/resources/desktop/shortcuts/desktop_add_shortcut.png)

You can enter a name, description and create a list of commands.
  
![add shortcut](/resources/desktop/shortcuts/desktop_add_empty_window.png)

At the bottom there is a drop-down list with available basic git commands.  
  
![picker](/resources/desktop/shortcuts/desktop_add_picker.png)
  
A list of commands appears in the middle of the window. You can edit, move, and delete them. New commands are added after the currently selected command.
  
![command list](/resources/desktop/shortcuts/desktop_add_command_list.png)
  
You can click **Edit File** and edit the raw bash file.  
  
![edit file](/resources/desktop/shortcuts/desktop_add_edit_file.png)
  
After clicking **Add** next to the command, a window with the command settings opens. Here you can add additional flags and input.
Below is the **Use command input** button. Checking this means the shortcut has an input that will be asked for each time it's launched. In the example above, this is the name of the new branch.
  
![command settings](/resources/desktop/shortcuts/desktop_command_settings.png)
  
You can also add a custom command with your own text. To make the command ask for input upon startup, you can enter `$1` - this will be filled in with the input upon startup. There can only be one input for the entire command sequence. 
  
![custom command](/resources/desktop/shortcuts/desktop_custom_command.png)
  
After generating the list of commands, click **Save**.
  
A list of shortcuts will be displayed here. You can also edit or delete a shortcut. To launch it, click the button:
  
![list of shortcuts](/resources/desktop/shortcuts/desktop_list_of_shortcuts.png)
  
If the team has input, it will ask for it: 
  
![shortcut input](/resources/desktop/shortcuts/desktop_shortcut_input.png)
  
The result will be displayed in the terminal.

## An example of creating a Git shortcut

Let's take an existing example from the Git shortcuts documentation. I've completed work on issue **TICKET-12345** and am taking issue **TICKET-45678**. I need to perform a series of Git actions that take some time. For example, I'm using a fork that throws errors if I start a new action while the previous one is loading.
    
The entire process of switching to a new task takes 30 seconds to a minute and is sometimes exhausting.
  
Let's try to automate this. 
    
1. Tap **Add shortcut**
   ![add shortcut](/resources/desktop/shortcuts/desktop_add_shortcut.png)
2. Enter the name "Switch to another task"
   ![name](/resources/desktop/shortcuts/desktop_example_name_description.png)
3. Adding commands
   ![all commands](/resources/desktop/shortcuts/desktop_example_all_commands.png)
4. For `git checkout` you need to specify the input when running the command and the `-b` flag.
   ![command settings](/resources/desktop/shortcuts/desktop_example_command_settings.png)
5. For `git push` we also use input
6. This is the script we got.
   ![edit file](/resources/desktop/shortcuts/desktop_example_edit_file.png)
7. Tap **Save**
8. The command has appeared in the list. Let's run it.
   ![run command](/resources/desktop/shortcuts/desktop_example_list.png)
9. The command asks for input, enter the name of the new branch
   ![shortcut input](/resources/desktop/shortcuts/desktop_example_shortcut_input.png)
10. That's all :)