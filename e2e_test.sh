TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
PLAN="./plan.sh -D$TMP/.plans"

# plan
$PLAN pursuit n.query 'plan tests'
$PLAN add 'n.range input to queries'
$PLAN add 'n.multihome'
$PLAN ..note all possible queries or just most?
$PLAN ..note a sub queries, or handled in those programs
$PLAN pursuit n.command 'plan tests'
$PLAN add 'n.range input to commands'
$PLAN add '_.multihome'
$PLAN ..note dial in the api
$PLAN ..idea web service
$PLAN ..page message for testing
$PLAN ..page a second line for testing
$PLAN pursuit n.one 'dummy pursuit 01'
$PLAN add 'n.01 dummy a'
$PLAN ..idea dummy idea
$PLAN add 'n.01 dummy b'
$PLAN add '_.multihome'
$PLAN pursuit n.two 'dummy pursuit 02'
$PLAN ..idea dummy idea
$PLAN ..note dummy note
$PLAN add 'n.02 dummy a'
$PLAN add 'n.02 dummy b'
$PLAN add '_.multihome'
$PLAN pursuit _.query 'plan tests'
$PLAN stash take care of kitties
$PLAN stash get new sinks
$PLAN stash figure out quartermaster shit


#  n. # name
$PLAN add 'n.parse plan'
$PLAN add 'n.parse note'
$PLAN '-o_.parse note' add '_.query'
$PLAN add 'n.parse group'
$PLAN add 'n.parse pursuit'
$PLAN add 'n.parse hash'
$PLAN add 'n.parse key'
$PLAN add 'n.parse index'

#  _. # name regex
$PLAN header "name match"
$PLAN name '_.' | rev | cut -d'|' -f1 | rev \
| while read n
do
    $PLAN name "_.^$n\$"
done

#  r. # pursuit 
$PLAN header "pursuit match"
$PLAN name 'r.' \
| while read n
do  # cannot match beginning '^' b/c ref match is against <hash>|<refname>
    $PLAN name "r.$n\$"
done
$PLAN header "open and index"

#  o. # 
$PLAN name o.

#  i. # index
for i in $(seq $($PLAN ..id c. | wc -l))
do
    $PLAN name i.e.$i
done

#  p. # plan
$PLAN header "none parents; some parents"
$PLAN name p.
$PLAN open _.multihome
$PLAN name p. | cut -d'|' -f2 \
| while read p
do
    $PLAN name "p._.$p"
done

#  t. # plan
$PLAN header "tops"
$PLAN open t. | cut -d'|' -f2 \
| while read t
do
    $PLAN name "t._.$t"
done

#  c. # plan
$PLAN header "children"
$PLAN open 't._.plan tests'
$PLAN open c._.query
$PLAN name c. | cut -d'|' -f2 \
| while read c
do
    $PLAN name "c._.$c"
done

#  s. # plan
$PLAN header "stash"
$PLAN name s. | cut -d'|' -f2 \
| while read s
do
    $PLAN name "s._.$s"
done

#  g. # plan
$PLAN header "groups"
$PLAN name g. | cut -d'|' -f2- \
| while read g
do
    gr=$(echo "$g" | cut -d'|' -f1)
    n=$(echo "$g" | cut -d'|' -f2)
    nm=$($PLAN name "g.$gr._.$n")
    printf '%s: %s\n' "$gr" "$nm"
done | sort


# group
#  *  # regex; not null; no creation
$PLAN header "group match"
$PLAN groups \
| while read gm
do
    $PLAN groups "$gm"
done 

# note
#  *  # regex; not null; creation
$PLAN header "note match"
$PLAN open 'r.plan tests'
$PLAN open c._.^command
$PLAN ..all \
| while read nt
do
    $PLAN header "$nt"
    $PLAN "..$nt"
done

# pursuit
#  *  # regex; not null; creation TODO verify always creates
$PLAN header "pursuit match"
$PLAN overview \
| while read pur
do
    $PLAN header "$pur"
    $PLAN overview "$pur"
done

# open
# name
# pursuit
# add
# stash
# groups
# overview
# *
# ^^

# status
$PLAN header "pursuit match"
$PLAN open 'r.plan tests'
$PLAN open 'c._.query'
$PLAN status toggle
$PLAN status false
$PLAN status false

# plan
$PLAN plan
# tree
# advance
# complete
$PLAN header "tree advance complete"
$PLAN '-or.plan tests' open c._.query
$PLAN advance
$PLAN advance s.3
$PLAN tree
$PLAN advance c.1
$PLAN tree
$PLAN complete
$PLAN tree

# show-stash
$PLAN header "stash"
$PLAN show-stash | $PLAN table

# tops
# table
# sort
$PLAN tops 1 | $PLAN sort 9 | $PLAN table
$PLAN tops 2 | $PLAN sort 2 | $PLAN table


# remove-pursuit
# remove
# move
# delete-note
# archive
# help
# parse-plan
# parse-note
# parse-group
# append
# delete-group
# delete-plan
# edit-procedure
# edit-stash
# set-pursuit


# TODO plan test set
# TODO do it

# determine plan cli' 'plan
# history: open, new
# show notes with hierarchy
# serialize
# documentation
# filter for table

