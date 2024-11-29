# Pointshop (DarkRP Edition)
 Fork of pointshop modified to be accessible through an NPC vendor on DarkRP. An NPC is not included, so if you want to use this, you will need to create your own NPC that calls `Player:PS_ToggleMenu()` when used.

## List of Changes
- All means of accessing the shop through concommands, chat commands, and buttons have been removed.
- All references to points have been removed, and all functions that checked or modified a player's points have been replaced with their DarkRP counterparts.
- Notification system has been replaced with the DarkRP one.
- Added additonal items and removed many default ones.
