"""Minimal read-only MPQ (v1) reader, no dependencies.

Supports hashed file lookup, encrypted hash/block tables, sector-split and
single-unit files, zlib / bzip2 sector compression and file-key decryption.
Enough to pull DBFilesClient\\*.dbc out of 1.12-era patch archives.
"""
import bz2
import struct
import zlib

_CRYPT = []


def _init_crypt():
    seed = 0x00100001
    table = [0] * 0x500
    for i in range(0x100):
        idx = i
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            t1 = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            t2 = seed & 0xFFFF
            table[idx] = t1 | t2
            idx += 0x100
    return table


def _hash(s, kind):
    if not _CRYPT:
        _CRYPT.extend(_init_crypt())
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in s.upper().encode("latin-1"):
        seed1 = (_CRYPT[kind * 0x100 + ch] ^ (seed1 + seed2)) & 0xFFFFFFFF
        seed2 = (ch + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def _decrypt(data, key):
    if not _CRYPT:
        _CRYPT.extend(_init_crypt())
    out = bytearray()
    seed = 0xEEEEEEEE
    n = len(data) // 4
    words = struct.unpack("<%dI" % n, data[:n * 4])
    for w in words:
        seed = (seed + _CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        v = (w ^ ((key + seed) & 0xFFFFFFFF)) & 0xFFFFFFFF
        key = ((((~key) << 0x15) + 0x11111111) | (key >> 0x0B)) & 0xFFFFFFFF
        seed = (v + seed + (seed << 5) + 3) & 0xFFFFFFFF
        out += struct.pack("<I", v)
    return bytes(out) + data[n * 4:]


FLAG_IMPLODE = 0x00000100
FLAG_COMPRESS = 0x00000200
FLAG_ENCRYPTED = 0x00010000
FLAG_FIX_KEY = 0x00020000
FLAG_SINGLE_UNIT = 0x01000000
FLAG_EXISTS = 0x80000000


class MPQ:
    def __init__(self, path):
        self.f = open(path, "rb")
        head = self.f.read(32)
        off = 0
        while head[:4] != b"MPQ\x1a":
            if head[:4] == b"MPQ\x1b":
                user = struct.unpack("<4sIII", head[:16])
                off = user[2]
                self.f.seek(off)
                head = self.f.read(32)
                continue
            off += 0x200
            self.f.seek(off)
            head = self.f.read(32)
            if len(head) < 32:
                raise ValueError("no MPQ header")
        self.base = off
        (_, _, _, _, sector_shift, ht_off, bt_off, ht_n, bt_n) = struct.unpack("<4sIIHHIIII", head)
        self.sector = 512 << sector_shift
        self.f.seek(self.base + ht_off)
        ht = _decrypt(self.f.read(ht_n * 16), _hash("(hash table)", 3))
        self.hashes = [struct.unpack("<IIHHI", ht[i * 16:(i + 1) * 16]) for i in range(ht_n)]
        self.f.seek(self.base + bt_off)
        bt = _decrypt(self.f.read(bt_n * 16), _hash("(block table)", 3))
        self.blocks = [struct.unpack("<IIII", bt[i * 16:(i + 1) * 16]) for i in range(bt_n)]

    def _find(self, name):
        n = len(self.hashes)
        start = _hash(name, 0) % n
        a, b = _hash(name, 1), _hash(name, 2)
        i = start
        while True:
            ha, hb, _, _, blk = self.hashes[i]
            if blk == 0xFFFFFFFF:
                return None
            if ha == a and hb == b and blk != 0xFFFFFFFE:
                return self.blocks[blk]
            i = (i + 1) % n
            if i == start:
                return None

    def has(self, name):
        blk = self._find(name)
        return bool(blk and blk[3] & FLAG_EXISTS)

    @staticmethod
    def _decompress(data, expected):
        if len(data) == expected:
            return data
        mask = data[0]
        payload = data[1:]
        if mask & 0x10:
            payload = bz2.decompress(payload)
        if mask & 0x02:
            payload = zlib.decompress(payload)
        if mask & ~0x12:
            raise ValueError("unsupported compression 0x%02x" % mask)
        return payload

    def read(self, name):
        blk = self._find(name)
        if not blk or not blk[3] & FLAG_EXISTS:
            raise KeyError(name)
        pos, csize, fsize, flags = blk
        if flags & FLAG_IMPLODE:
            raise ValueError("PKWARE implode not supported: " + name)
        key = None
        if flags & FLAG_ENCRYPTED:
            key = _hash(name.replace("/", "\\").split("\\")[-1], 3)
            if flags & FLAG_FIX_KEY:
                key = ((key + pos) ^ fsize) & 0xFFFFFFFF
        self.f.seek(self.base + pos)
        raw = self.f.read(csize)
        if flags & FLAG_SINGLE_UNIT:
            if key is not None:
                raw = _decrypt(raw, key)
            return self._decompress(raw, fsize) if flags & FLAG_COMPRESS else raw[:fsize]
        if not flags & FLAG_COMPRESS:
            if key is None:
                return raw[:fsize]
            out = bytearray()
            for s in range(0, fsize, self.sector):
                out += _decrypt(raw[s:s + self.sector], (key + s // self.sector) & 0xFFFFFFFF)
            return bytes(out[:fsize])
        nsec = (fsize + self.sector - 1) // self.sector
        table = raw[:(nsec + 1) * 4]
        if key is not None:
            table = _decrypt(table, (key - 1) & 0xFFFFFFFF)
        offs = struct.unpack("<%dI" % (nsec + 1), table)
        out = bytearray()
        for s in range(nsec):
            chunk = raw[offs[s]:offs[s + 1]]
            if key is not None:
                chunk = _decrypt(chunk, (key + s) & 0xFFFFFFFF)
            expected = min(self.sector, fsize - s * self.sector)
            out += self._decompress(chunk, expected)
        return bytes(out)
