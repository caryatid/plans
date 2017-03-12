TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
PLAN="./plan.sh -D$TMP/.plans"

$PLAN pursuit 'n.studio' ..musician
$PLAN add o. 'n.room build out'
$PLAN add o. 'n.determine deck'

$PLAN pursuit 'n.spanish' ..language
$PLAN add o. 'n.pick movies'

$PLAN pursuit 'n.woodworking' ..home
$PLAN add o. 'n.kitty door'

$PLAN pursuit n.haskell ..programming
$PLAN add o. 'n.road to math book'

$PLAN pursuit n.lua programming

$PLAN pursuit n.gurgeh ..games
$PLAN add o. n.design
$PLAN add o. n.code
$PLAN note o. design composing in ascii?
$PLAN note o. design seperate game and display?

$PLAN pursuit n.philosophy ..reading
$PLAN add o. n.baudrillard
$PLAN add o. 'n.critical theory'

$PLAN pursuit n.fiction ..reading
$PLAN add o. n.erikson
$PLAN note o. n think about what to read

$PLAN pursuit n.gaming-machine ..games

$PLAN pursuit n.automata ..games
$PLAN add o. n.design
$PLAN add o. n.code
$PLAN add o. n.missions


$PLAN pursuit n.chef ..home
$PLAN add o. n.equipment
$PLAN add o. n.technique
$PLAN add i.o.:e.1 n.stock
$PLAN add i.o.:e.1 n.sauce
$PLAN add i.o.:e.1 n.roast
$PLAN add o. n.recipes
$PLAN add i.o.:e.1 'n.squash soup'
$PLAN add o. n.meals
$PLAN add i.o.:e.1 'n.chicken and soup'
$PLAN add '_.chicken and soup' '_.squash soup'

$PLAN note o. n link recipes into meals by name
$PLAN note o. n force a schedule

$PLAN pursuit n.cycle-tour ..body
$PLAN add o. n.equipment
$PLAN add o. n.fitness

$PLAN pursuit 'n.teach christina' ..programming
$PLAN add o. 'n.shell'
$PLAN add o. 'n.other languages'
$PLAN add o. 'n.improve plan.sh'

$PLAN pursuit 'n.plans program' ..programming
$PLAN add o. '_.improve plan.sh'
$PLAN add o. 'n.archive'
$PLAN add i.o.:e.1 'n.save'
$PLAN add i.o.:e.1 'n.restore'
$PLAN add o. 'n.finalize end to end'
$PLAN add o. n.ideas
$PLAN open i.o.:e.1
$PLAN add o. 'n.serialization'
$PLAN add o. 'n.pipe commands'
$PLAN add o. 'n.api'
$PLAN add o. 'n.Makefile'


$PLAN tops | $PLAN tree
