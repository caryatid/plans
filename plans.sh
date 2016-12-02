# # # # # # plans:
# 
# sregex
# tree
# haskell book
# baudrillard
# go mastery
# nethack mastery
# disciplined
# drum patterns
# structures
# 
#     # <plan action>: <what plan action determines>
# sregex:
#     - intent: implement sre for pipelines
#     - milestones: {ui, data model, operations}
#     - procedure: {filesystem, key-val, rdbms} -> ui
#                  {extract, yank, substitute...} -> operations
#     -> recurse
# 
# disciplined:
#     - intent: maintain habitual behavior beneficial to mind and body
#     - milestones: {plan set, 10 days, 30 days, 90 days, year}
#     - procedure: {attempt simple plan, modify plan if wanted } -> plan set
#                  {calendar marking, journal, reward} -> 10 day               
#     -> recurse
# 
# $ plan new-ref sregex _sregex  
# af12aac233... # hash of new plan with name and reference "sregex"
# $ plan open sregex # sets "sregex" as current plan
# $ plan intent # intent to stdout. "sregex" plan now implicit
# implementation sre for pipelines
# $ plan milestone _data-model _operations _api
# $ plan add _use-pattern _data-requirements \
#            name:data-model name:operations _testing _refactor-pass name:api
# # stows message in a global queue. just a scratch pad really. appends info from open plan
# $ plan stash "all selectors are limited by currently open plan's descendents by default?"
# $ plan organize... # simple manual procedure reorganization using the EDITOR
# $ plan open use-pattern
# $ plan intent <<<"determine cmd line interface"
# $ plan add _read-paper _interface
# $ plan stash "new selectors for plans - like p: for parents or somesuch" 
# $ plan set-key name:read-paper source <<<"http://doc.cat-v.org/bell_labs/structural_regexps/se.pdf"
# $ plan set-key name:interface intent <<<"describe interface"
# 
# 
# argument types:
#     cmd -- startswith
#     plan -- filter full set by
#         parents
#         current
#         ref-name
#         history
#     value -- regex
# 

state
    - current plan -- global
    - milestones -- union of global and local
    - plan dirs -- union of global and local
    - stash -- global ;; references current plan 
    - history -- global ;; references current plan 
    - refs -- union of global refs and plan refs


    global config 
        ~/.plans
    local config
        pwd upwards to nearest .plans dir
        
cmd=intent
test -n "$1" && { cmd=$1; shift :}
case $cmd in
open)
    echo foo
    ;;
intent)
    echo foo
    ;;
milestone)
    echo foo
    ;;
add)
    echo foo
    ;;
stash)
    echo foo
    ;;
organize)
    echo foo
    ;;
esac




    