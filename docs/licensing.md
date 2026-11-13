# SCH1 school licence codes

This is the code format the unlocker uses. The server checks codes offline. The private signing key stays with the unlocker and is not in this repository.

The server embeds this Ed25519 public key, XOR-masked, and checks its SHA-256 before use:

```
ZkcJSxU7JEYxawOUEmoUgoUyxX5EUoGALz3o3DSgEtU=
```

## What the unlocker needs

- The machine id, typed or scanned from the QR code on the lock screen
- The school name, UTF-8, 1 to 60 bytes (60 bytes is allowed, 61 is rejected)
- The issue day and the expiry day
- The maximum number of phones and computers, or 0 for unlimited

## Machine id

The lock screen shows 16 characters in groups of 4, for example `Y4MS-W8N9-QME2-0EE3`.

Those 16 characters are the first 10 bytes of a SHA-256, written in Crockford base32.

The hashed text is exactly:

```
SCH-MID|H0:<board serial>|H1:<cpu id>|H2:<disk serial>
```

There are no spaces around the values.

On Windows:

- H0 is the baseboard serial (`Win32_BaseBoard.SerialNumber`)
- H1 is the CPU id (`Win32_Processor.ProcessorId` of the first processor)
- H2 is the first disk serial (`Win32_DiskDrive.SerialNumber`)
- Any missing part, or a value that is only zeros, is replaced by `G:<Windows MachineGuid>`
- MachineGuid is `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`

On the Raspberry Pi and other Linux servers:

- H0 is the `Serial` line in `/proc/cpuinfo`
- H1 is `/etc/machine-id`
- H2 is the root disk serial, or the root filesystem UUID when the serial is missing
- Any missing part, or a value that is only zeros, is replaced by `G:<machine-id>`

The QR payload is the ASCII string `SCH1:` followed by the dashed machine id:

```
SCH1:Y4MS-W8N9-QME2-0EE3
```

The raw 10 bytes of that example are hex `f1299e22a9bd1c2039c3`.

## Days

Day 0 is 2024-01-01 UTC. Each step is one UTC calendar day.

- 2026-11-13 is day 1047
- 2027-11-12 is day 1411

`expiryDay` 0 means the code never ends. `maxDevices` 0 means unlimited devices.

The expiry day is still a valid day. The following UTC day is not. A code is also not valid before its issue day.

## Code body

The body is this byte layout, big-endian:

| Offset | Size | Field |
| --- | --- | --- |
| 0 | 1 | Version. Must be `1`. |
| 1 | 2 | Issue day, `u16` big-endian |
| 3 | 2 | Expiry day, `u16` big-endian. `0` = never |
| 5 | 2 | Max devices, `u16` big-endian. `0` = unlimited |
| 7 | 1 | School name length in bytes, 0 to 60 |
| 8 | nameLen | School name, UTF-8, no longer than 60 bytes |

Example for Hope Academy, issued 2026-11-13, expires 2027-11-12, 40 devices:

```
01 0417 0583 0028 0c 486f70652041636164656d79
```

`486f70652041636164656d79` is the UTF-8 for `Hope Academy`.

## Signature

The signed message is the raw bytes:

```
ASCII "SCH1" || machine id raw 10 bytes || body
```

Sign that message with Ed25519. The signature is 64 bytes. Append it to the body:

```
code bytes = body || signature
```

Anything that is not this layout is rejected: wrong version, name longer than 60 bytes, invalid UTF-8, truncated signature, extra bytes, or padding bits that are not zero.

## Crockford base32

Alphabet, in value order 0..31:

```
0123456789ABCDEFGHJKMNPQRSTVWXYZ
```

Encode most-significant bit first. Do not add `=` padding. Leftover bits in the last symbol are zero.

The machine id is 10 bytes, so it is always 16 symbols, shown as `XXXX-XXXX-XXXX-XXXX`.

The code is `ceil(len(body+signature) * 8 / 5)` symbols, shown in groups of 5 separated by `-`. A 12-byte name makes a 20-byte body, 84 bytes with the signature, and 135 symbols (27 groups of 5).

Before checking, the server cleans typed text:

1. Uppercase
2. `O` becomes `0`
3. `I` and `L` become `1`
4. Every character that is not a letter or a digit is removed

`U` is not in the alphabet and is rejected. Dashes and spaces are ignored.

## Worked code

Machine id `Y4MS-W8N9-QME2-0EE3` and this code:

```
0421E-1C300-M0RJ3-FE1JJ-0GB3C-5J6AV-BSD27-FSFSJ-9XMNT-7PZY8-GG8Z1-05DSV-GH28T-2M9F3-NFJET-MWZVQ-934HS-7T4QJ-QRPWF-RTMKD-ZVEN5-8N1J2-A38ZY-FYH3D-WR1M9-6TFGQ-3EY08
```

must verify as:

- School: `Hope Academy`
- Issued: 2026-11-13
- Expires: 2027-11-12
- Max devices: 40

The same code must fail for every other machine id.

## After a code is accepted

The server stores an AES-256-GCM file on that computer. The file key is wrapped under each pair of the three hardware parts, so one replaced part still opens it and a copy on another computer does not. This file is not part of code generation. When an expiry is set, the server also stores the last time it was opened and refuses a clock that has been set backwards.
