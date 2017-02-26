TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
PLAN="./plan.sh -D$TMP/.plans"

# hash
echo end to end plan test
echo --------------------


$PLAN pursuit 'n.determine plan cli' 'plan'
$PLAN add 'n.end to end'
$PLAN -oi.1 add 'n.define commands'
$PLAN -oi.1 add 'n.define query language'
$PLAN open r.plan
$PLAN add 'n.think about missing ideas'
$PLAN add 'n.determine types'
$PLAN add 'n.doc api'

$PLAN tree
$PLAN pursuit 'n.design the game' 'gurgeh'
$PLAN stash ensure self move works. If self move is still around
$PLAN edit-note ideas meld og gurgeh and nethack like ideas
$PLAN edit-note ideas a meld og gurgeh and nethack like ideas
$PLAN show-note wow  # displays notes hierarchy 

$PLAN open g. 
$PLAN pursuit 'n.want' 'album' 
$PLAN add 'n.determine electronics'
$PLAN add 'n.practice fingering'.
# opens other, adds, returns to previous open
$PLAN add 'n.experiment with rhythms via electronics'
$PLAN groups 
$PLAN pursuit 'n.wasd station' 'computing environment'
$PLAN open r.plan
$PLAN add 'n.move plan up and down'

$PLAN pursuit 'n.package for my toolbox' 'computing environment'
$PLAN add 'n.sources'
$PLAN add 'n.Makefile'
$PLAN overview 'computing environment'
