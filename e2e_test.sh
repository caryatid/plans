TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
PLAN="./plan.sh -D$TMP/.plans"

$PLAN open 'n.build out' 
$PLAN add o. 'n.construction'
$PLAN add o. 'n.gear'
$PLAN add o. 'n.recording tests'
$PLAN add 'n.studio' o.

$PLAN open 'n.learn-spanish'
$PLAN add o. 'n.find movies'

$PLAN open n.woodworking
$PLAN add o. 'n.kitty door'

$PLAN open n.haskell
$PLAN add o. 'n.road to math book' 

$PLAN stash learn lua

$PLAN stash learn how other programs parse
$PLAN add  i.s.:1 'n.redis'
$PLAN add  i.s.:1 'n.nethack'
$PLAN add  i.s.:1 'n.shell'

$PLAN open n.gurgeh 
$PLAN add o. 'n.intent'
$PLAN add o. 'n.model'
$PLAN add i.o.:e.1 'n.engine'
$PLAN add i.o.:e.1 'n.assets'
$PLAN add i.o.:e.1 'n.interface/api'
$PLAN add o. 'n.story'
$PLAN note o. 'design composing in ascii?'
$PLAN note o. 'design seperate game and display?'

$PLAN open n.philosophy
$PLAN add o. n.baudrillard
$PLAN add o. 'n.critical theory'

$PLAN open n.fiction
$PLAN add o. n.erikson
$PLAN note o. n think about what to read

$PLAN open n.gaming-machine

$PLAN open n.automata
$PLAN add o. n.design
$PLAN add o. n.code
$PLAN add o. n.missions

$PLAN add n.gaming o.

$PLAN add _.gaming$ '_.gaming-machine'

$PLAN open n.chef 
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

$PLAN open n.cycle-tour 
$PLAN add o. n.equipment
$PLAN add o. n.fitness

$PLAN open 'n.teach christina'
$PLAN add o. 'n.shell'
$PLAN add o. 'n.other languages'
$PLAN add o. 'n.improve plan.sh'

$PLAN open 'n.plans program'
$PLAN add o. 'n.work out plans dir'
$PLAN add o. 'n.overview'
$PLAN add o. 'n.display plan'
$PLAN add o. 'n.query output'
$PLAN add o. 'n.command outputs'
$PLAN add o. 'n.archive file name'
$PLAN add o. 'n.finalize end to end'
$PLAN add o. 'n.Makefile'
$PLAN add o. n.ideas
$PLAN open i.o.:e.1
$PLAN add o. 'n.list should not show index; for simpler manipulation'
$PLAN add o. 'n.serialization'
$PLAN add i.o.:e.1 'n.simple redis protocol?'
$PLAN add o. 'n.bookmark queries'
cat <<'EOF' | $PLAN note i.o.:e.1 details -
bookmark queries: 
the query string not the result is what
gets remembered
EOF
$PLAN add o. 'n.pipe commands'
$PLAN add o. 'n.api'
$PLAN add o. 'n.full tests'

$PLAN archive
$PLAN tops | $PLAN tree
