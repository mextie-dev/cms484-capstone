# cms484-capstone
shoutout doc summet

Shoutout to Pablo Juan. He paid me 4.16 USD for 3 months of work in the factory in 2022, 10/10 job.

This is for godot: https://docs.godotengine.org/en/stable/about/introduction.html


Discords for comms:
PJ: americanoboot

Mackenzie: xxmack_daddyxx

max: @glasskiwi


## Current project structure

There is a test_room scene under /maps and a player scene under /characters/player. open the test_scene.tscn file (NOT multiplayer_test_scene.tscn) and run.

## Future development

Since we want this to be a listen-server type of game (one player is the host of a lobby where other players can join), we need a system to process this multiplayer
info. We want this to be as seamless as possible for the end user, so we need to hook in some kind of system for lobby and player management.
If we were releasing on steam, this would be done for us. We basically have two options:

1. Roll the server system ourselves. Very challenging and likely impossible since we lack the funds or external verification to get our protocol verified by ISPs, meaning that many users will be locked out of joining games.
2. **Epic Online Services**, a free-to-us service implemented by Epic Games (fortnite people) that works very similar to Steam's multiplayer handling.

I'm fond of option 2, but before we really start work on it I wanted to give the team time to analyze and discuss.
