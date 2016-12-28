# API
## CORE
return-parse List String -> None|Item|List
plan-dir -> FilePath
hash-dir -> FilePath
make-header String String -> String
err-msg List -> String -> ErrorCode -> List
temp-dir -> FilePath
init -> PlanDir

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
Bool := true|false
BoolSet := true|false|toggle
CmdQ := query of cmd # TODO

DirectoryPath 
Display := sparkles
ErrorCode
FilePath

GroupQ := query for Groups # TODO
Hash := sha1
HashList := [sha1]
HashQ := query for hashes # TODO
HashWrite := modifies a hash
HashX := executes hash program
IdxQ := set of idx
Key := key string ( no spaces )
KeyQ := query for keys
List := String with newlines
None|Item|List := Ternary from _return_parse
PlanDir
PlanQ := query for plans
PlanWrite := modifies a plan
RefQ := query for references
RefWrite := modify references
Stdin := takes stdin for stuff
String := String without newlines
