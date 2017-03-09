TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
PLAN="./plan.sh -D$TMP/.plans"

$PLAN pursuit 'n.studio' musician
$PLAN add o. 'n.room build out'
$PLAN add o. 'n.determine deck'

$PLAN pursuit 'n.spanish' language
$PLAN add o. 'n.pick movies'

$PLAN pursuit 'n.woodworking' home
$PLAN add o. 'n.kitty door'

$PLAN pursuit n.haskell programming
$PLAN add o. 'n.road to math book'

$PLAN pursuit n.lua programming

$PLAN pursuit n.gurgeh games
$PLAN add o. n.design
$PLAN add o. n.code

$PLAN pursuit n.philosophy reading
$PLAN add o. n.baudrillard
$PLAN add o. 'n.critical theory'

$PLAN pursuit n.fiction reading
$PLAN add o. n.erikson

$PLAN pursuit n.automata games
$PLAN add o. n.design
$PLAN add o. n.code
$PLAN add o. n.missions


$PLAN pursuit n.chef home
$PLAN add o. n.equipment
$PLAN add o. n.meals
$PLAN add o. n.technique

$PLAN pursuit n.cycle-tour body
$PLAN add o. n.equipment
$PLAN add o. n.fitness

$PLAN pursuit 'n.teach christina' programming
$PLAN add o. 'n.shell'
$PLAN add o. 'n.other languages'
$PLAN add o. 'n.improve plan.sh'

$PLAN pursuit 'n.plans program' programming
$PLAN add o. '_.improve plan.sh'
$PLAN add o. 'n.archive'
$PLAN add i.o.:e.1 'n.save'
$PLAN add i.o.:e.1 'n.restore'
$PLAN add o. 'n.finalize end to end'


$PLAN tops | $PLAN tree
