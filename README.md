# Duane Blehm's Code

This is an archive of the Duane Blehm's source code.  Duane Blehm was an
early game developer for the Macintosh.  He released three games in the
1980's:
[Zero Gravity](http://www.macintoshrepository.org/4249-zero-gravity-),
[StuntCopter](http://www.macintoshrepository.org/5314-stuntcopter), and
[Cairo ShootOut!](http://www.macintoshrepository.org/4856-cairo-shootout-).

As a preteen computer nerd and budding developer, I not only loved the
games, but also had an interest in how a real application was made.
The About screens for the games offered source code printouts and unlock
codes for a small fee, so I saved up my allowance for a month or two,
stuffed a few bills and a note into an envelope, and mailed it off.

I received a reply about a year later.  It was from Blehm's parents,
gently explaining that their son had passed away and they couldn't offer
the source code.  They returned my money.  I was too young and lucky to
have much experience with death.  When I read the news, I remember
feeling a pang of... something.  I never forgot this feeling, and I
never forgot about the source code.

Some years later (a little over fifteen of them), Apple released a
Newton that ran NeXTSTEP and had cell phone radio.  I was done becoming
a programmer and on to becoming a better one.  I thought that porting
Zero Gravity to the iPhone would be a fun project, and began looking for
the source code again so that I could get the physics exactly right.

Despite the best efforts of a small LiveJournal community, I came up
empty.  I had enough other projects that I lost interest in that one
for the time being.

But, just like before, I never stopped thinking about the code.
I decided earlier this year that it had been long enough since my last
try, and in 2016 the venue of choice was Twitter.  I pecked out a short
plea for help, and in a hail-mary attempt to reach someone who had some
idea of how to help, I cc'ed Avadis Tevanian, Jr., who most people know
as a longtime VP at Apple but I remember primarily as the developer of
a beloved Missile Command port called MacCommand, and John Calhoun, who
wrote the fantastic paper-airplane game Glider.

Avi Tevanian doesn't tweet, really.  But John Calhoun did.  Suddenly I
had the source code.

So here it is, offered without license or warranty, the code for all
three of Duane Blehm's releases.  I've converted line endings to LF and
detabbed the files according to Blehm's preference for three-space tab
stops, and I wrote this README and a top-level Makefile, but the rest was
his and now it's ours.

Rest in peace, Duane Blehm.  Thanks for the games.


## Contents

    ├── Duane Blehm's Code                  Data forks
    │   ├── Animation ƒ
    │   ├── Cairo ƒ
    │   ├── Copy Mask ƒ
    │   ├── Drag Piece ƒ
    │   ├── More Info*
    │   ├── Regions ƒ
    │   ├── StuntCopter ƒ
    │   └── Zero Gravityƒ
    │
    ├── __MACOSX                            Resource forks
    │   └── Duane Blehm's Code
    │       ├── Animation ƒ
    │       ├── Cairo ƒ
    │       ├── Copy Mask ƒ
    │       ├── Drag Piece ƒ
    │       ├── More Info*
    │       ├── Regions ƒ
    │       ├── StuntCopter ƒ
    │       └── Zero Gravityƒ
    │
    ├── Duane Blehm's Code.zip              Original source dump
    │
    ├── Makefile                            Run `make` to rebuild this archive
    │
    └── README.md                           This file



## Maintainer

Pete Gamache, [pete@gamache.org](mailto:pete@gamache.org).

