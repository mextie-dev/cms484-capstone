# cms484-capstone
shoutout doc summet

Shoutout to Pablo Juan. He paid me 4.16 USD for 3 months of work in the factory in 2022, 10/10 job.

This is for godot: https://docs.godotengine.org/en/stable/about/introduction.html


Discords for comms:
PJ: americanoboot

Mackenzie: xxmack_daddyxx

max: @glasskiwi

Benton: dr.pepper2109


## Current project structure

There is a test_room scene under /maps and a player scene under /characters/player. open the test_scene.tscn file (NOT multiplayer_test_scene.tscn) and run.

## Future development

Since we want this to be a listen-server type of game (one player is the host of a lobby where other players can join), we need a system to process this multiplayer
info. We want this to be as seamless as possible for the end user, so we need to hook in some kind of system for lobby and player management.
If we were releasing on steam, this would be done for us. We basically have a few options:

1. Roll the server system ourselves. Costs money, but not a lot given we're estimating, what, 50 concurrent players at most?
2. Godot's integrated server system, which obv is easiest and tightest integrated but does not allow for browsing lobbies, only direct connection via a code or IP.
3. Epic Online Services, a free-to-us service implemented by Epic Games (fortnite people) that works very similar to Steam's multiplayer handling, but can be very heavy for a smaller game like this and also relies on a per-device account system. there's an existing addon that pairs this in with godot, and I already have establisment as an "Epic Developer" giving us access to the system.

I'm fond of option 3, but before we really start work on it I wanted to give the team time to analyze and discuss.


Summet's comments	8/37/2026
"why the gamification with ingame currency. What are we trying to do there"
	Same reason why duolingo is gamified. 
"so metaverse but for rollins"
	Kinda
"Muliplayer aspect may be more intriguing aspect. "
	Online chatroom
		"idea of identities, privacy, and all those sorts of things.
		Once you start doing multiplayer online networks, you start
		entering the realm of personal identity & privacy"
			way you used to connect to IRC back in the day.
			Player progression stored locally. Not networked as 			to maintain info across lobbies.
Currently passable; core crunch is good;
"I encourage you to talk about scope; What is the minimal piece of this that needs working. What are the sketch goals? If we have to punt entirely onto the Multiplayer, what does that look like? Which of those are your priorities? Which are your sketch goals? What pieces does our project fail if we have to punt things? Defining those things more concretely is a good use of time."
We have proof of concept, but we are encouraged on Project planning for sprint 1. Grand vision is the biggest point of contempt for many students. Key to success is starting with core technologies & use cases, & then building out from there.

