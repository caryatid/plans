# API
## CORE
return-parse List String -> None|Item|List
plan-dir -> FilePath
hash-dir -> FilePath
make-header String String -> String
err-msg List -> String -> ErrorCode -> List
temp-dir -> FilePath
init -> FilePath

## HASH
list-hashes -> HashList
id HashQ -> Hash
delete HashQ -> HashWrite
delete-key HashQ KeyQ -> HashWrite
key HashQ KeyQ -> List
set Stdin HashQ KeyQ -> HashWrite
edit HashQ KeyQ -> HashWrite
parse-hash HashQ -> Hash
parse-key HashQ KeyQ -> Key
append Stdin CmdQ -> List

## PLAN
rm-ref RefQ -> PlanWrite
open PlanQ -> RefWrite
data PlanQ -> List
organize PlanQ -> PlanWrite
ref PlanQ RefQ -> RefWrite
status PlanQ BoolSet -> Bool
advance PlanQ IdxQ -> PlanWrite
remove PlanQ PlanQ -> PlanWrite
add PlanQ PlanQ IdxQ -> PlanWrite
move PlanQ PlanQ PlanQ IdxQ -> PlanWrite
group-member PlanQ PlanQ GroupQ -> PlanWrite
group-add PlanQ PlanQ GroupQ -> PlanWrite
group-remove PlanQ PlanQ GroupQ -> PlanWrite
archive DirectoryPath
help 
list PlanQ -> Display
hash CmdQ PlanQ * -> HashX

# DATA
CmdQ := query of cmd 
GroupQ := query for Groups 
HashQ := query for hashes 
IdxQ := query of index
KeyQ := query for keys
PlanQ := query for plans
RefQ := query for references

HashWrite := modifies a hash
PlanWrite := modifies a plan
RefWrite := modify references
HashX := executes hash program

Hash := sha1
HashList := [sha1]
Bool := true|false
BoolSet := true|false|toggle
Key := key string ( no spaces )
List := String with newlines
None
Item := somewhat special. really just a single item list
Stdin := takes stdin for stuff
String := String without newlines
Display := sparkles

ErrorCode
FilePath
DirectoryPath 

