# Pointshop (DarkRP Edition)
 Fork of pointshop modified to be accessible through an NPC vendor on DarkRP. An NPC is not included, so if you want to use this, you will need to create your own NPC that calls `Player:PS_ToggleMenu()` when used.

## List of Changes
- All means of accessing the shop through concommands, chat commands, and buttons have been removed.
- Removed the provider system. Data will always be stored through PData.
- All references to points have been removed, and all functions that checked or modified a player's points have either been removed or replaced with their DarkRP counterparts.
- Notification system has been replaced with the DarkRP one.
- Added additional items and removed many default ones.
