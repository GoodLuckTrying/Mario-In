# Native Contra lives-screen reference

Captured in Mesen from the unchanged local Contra (USA) ROM, SHA-256
`1f4a9b3f04e2f828688512c0b83611a87c3fc1bd4f85ed91da1b19abc5816d73`.
`build/probe-lives.lua` uses controller Start at frames 120/200 and Select
at 180 for two players, then captures the Jungle intro during the score's
visible phase. The RGB files contain the complete 256x240 framebuffer.

`lives-font.chr` records the original $1000..$1FFF PPU page. Tests compare
$1000..$1F7F: the pinned native bank4 source documents graphic_data_01's
transfer as [$0CE0,$1F80), leaving its final eight tiles untouched.

The fixed ROM matches both complete reference images and the native font,
on a fresh start and after completing an actual attract sequence.
