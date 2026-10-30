"""Decode the original renderer's complete metasprite table and CHR transfers."""
POSE_TABLE = 0x8FBE
POSE_COUNT = (0x919C-POSE_TABLE)//2
CUSTOM_CHR_SIZE = 122*16


def metasprites(rom):
    def byte(address):
        assert 0x8000 <= address < 0xC000
        return rom[16+address-0x8000]
    result = []
    for pose in range(POSE_COUNT):
        entry = POSE_TABLE+pose*2
        pointer = byte(entry)+256*byte(entry+1)
        count = byte(pointer)
        cursor, saved, attribute = pointer+1, None, None
        records = []
        for _ in range(256):
            if not count:
                break
            y = byte(cursor)
            if y == 0x80:
                saved = cursor+3
                cursor = byte(cursor+1)+256*byte(cursor+2)
                continue
            if y == 0x81:
                assert saved is not None
                cursor = saved
                continue
            tile = byte(cursor+1)
            if not y & 1:
                attribute = byte(cursor+2)
            assert attribute is not None
            x = byte(cursor+(2 if y & 1 else 3))
            records.append({'y': (y if y < 128 else y-256)//2,
                            'tile': tile, 'attribute': attribute, 'x': x,
                            'tile_offset': 16+cursor+1-0x8000})
            cursor += 3 if y & 1 else 4
            count -= 1
        else:
            raise AssertionError(f'Invalid native pose {pose:02X}')
        result.append(records)
    return result


def sprite_remap(rom):
    used = {record['tile'] for pose in metasprites(rom) for record in pose}
    free = [tile for tile in range(1,256,2) if tile not in used]
    # Background art keeps its own complete original 8KB CHR bank. These are
    # unused SPRITE slots, and are never used to store background graphics.
    count = CUSTOM_CHR_SIZE//32
    assert len(free) >= count
    mapping = dict(zip(range(0,CUSTOM_CHR_SIZE//16,2),free[:count]))
    assert not set(mapping.values()) & used
    return mapping


def chr_transfers(rom, command):
    def byte(address):
        return rom[16+0x1C000+address-0xC000]
    entry = 0xFDBB+command*2
    cursor = byte(entry)+256*byte(entry+1)
    transfers = []
    while byte(cursor) != 0xFF:
        bank = byte(cursor)
        address = byte(cursor+1)+256*byte(cursor+2)
        destination = byte(cursor+3)+256*byte(cursor+4)
        length = byte(cursor+5)+256*byte(cursor+6)
        offset = 16+bank*0x4000+address-0x8000
        assert destination+length <= 0x2000
        transfers.append((offset,destination,length))
        cursor += 7
    return transfers
