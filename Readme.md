## Baldur's Gate 3 Mod - Manipulate Rolls

A mod to try and inject manually (or externally) determined D20 rolls in Baldur's Gate 3 Dialog D20 roll menus

Modes:
- You can use ScriptExtender debug console commands to manually set the value of the next die roll `!setnextd20 number`
- - `number` being an integer you type, range 1 to 20
- - if you run the command twice, intent is for advantage/disadvantage to use latest and previous as the two input die rolls
- See below for instead of manually running console commands you can connect a Bluetooth D20 (GoDice) to your PC and get the results from that die into the game

There is a Companion app [here](https://github.com/adowdy/goDice-writeToFile) -- Instead of using `!setnextd20` command, you can run the NodeJs app + server to connect to a bluetooth D20 (GoDice) and connect the die rolls into the BG3 mod
 (use a real D20 that injects the die result into the game!)

- Mod is WORK IN PROGRESS (i make no promises at the moment!). There are some bugs (sometimes we see that we cannot influence success/fail determination even after setting the die rolls into the game engine memory)

- based on Script Extender
https://github.com/Norbyte/bg3se

- Utilizes some Osiris Events notated here
https://github.com/LaughingLeader/BG3ModdingTools