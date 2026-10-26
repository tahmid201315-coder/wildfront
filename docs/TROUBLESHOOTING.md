# Troubleshooting

- **Game is slow:** Settings > Graphics quality > Low, and turn on performance mode. Lower render scale if offered.
- **Loading takes a while on first start:** audio and the island are generated at startup. This is normal.
- **"Pack full" when picking something up:** the item is placed on the ground nearby. Quest items always make room by setting down an ordinary stack.
- **Lost items after dying:** walk back to the glowing Death Cache and interact. It holds half of each stack you carried.
- **Cannot enter the Ashen Expanse safely:** craft the Environmental Suit (needs the Ironfall generator restarted) or use Heat Tonics.
- **Core Gate will not open:** you need the Core Key from the Furnace Colossus and the three pylons activated in the pulsing order. A wrong pylon resets the sequence.
- **Save says corrupt:** the game tries the backup automatically. If both fail, start a new game; report the message shown.
- **APK will not install:** allow installs from unknown sources, or uninstall an older build signed with a different debug key first.
- **CI import fails:** open `logs/import.log` in the `build-logs` artifact and look for the first SCRIPT ERROR.
