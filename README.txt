- archive concept can hopefully expand into multiple repository transfer and merge?
- generics could be data

data:
    - plans:
        - status
        - procedure
        - name
    - groups:
        - name
        - set of plans
    - generics:
        - name
        - creation definition
    - history:
        - list of (plan, <open ref name when added to history>)
    - references:
        - name
        - plan
    - procedures:
        - index position
        - list of plans
    - data:
        - name
        - data
        
queries:
    - plan: 
        - ref: <ref query>
        - history filter: 
            - ref: <ref query> 
            - <hash query>
        - index: <index query>
        - parents filter: <hash query> 
        - children filter: <hash query>
        - groups filter: <hash query>
        - any <hash query>
    - ref: regex | null := <open>
    - generic: regex | null := <tutorial>  TODO think about this
    - group: regex | null := <bucket>
    - index:  # TODO should be defined seperately for data
        - beginning: [+-]integer
        - current position | null: [+-]integer
        - end: [+-]integer

input:
    - <hash input>
    - data

output:
    full: 
        name: string
        id: string
        focus: boolean
        children: [oneline]
        group membership: generic list
        ref membership: generic list
        status: boolean
    oneline:
        name:  string
        id: string
        focus: boolean
        children: boolean
        group membership: boolean
        ref membership: boolean
        status: boolean
    parse fail: <hash output>
    generic list: basically 'cat'
    boolean: true|false|null
    tree: indended [oneline] via single plan as parent

commands:
    - null:
        - name: init-generic
          args: [<generic query>]
          side-effects: >
              TODO consider more structure here?
              creates a new set of plans, linked as the generic
              definition specifies.
        - name: rm-ref
          args: [<ref query>]
          side-effects: removes a reference entry.
        - name: ref
          side-effects: set a plan to a reference name
          args:
            - <plan query>
            - <ref query>
          side-effects: set a new reference name to a specific plan
        - name: open
          side-effects: sets the special "open" refernce name to a plan
          args: [<plan query>]
        - name: add
          side-effects: adds source to target
          args:
            target: <plan query>
            source: <plan query>
            position: <index query> | end
        - name: remove
          side-effects: removes source from target
          args:
            target: <plan query>
            source: <plan query>
        - name: move
          side-effects: moves source from target to destination
          args:
            target: <plan query>
            source: <plan query>
            desitination: <plan query>
            position: <index query> | end
        - name: group
          side-effects: add plan to group
          args:
            - <plan query>
            - <group query>
        - name: ungroup
          side-effects: remove plan from group
          args:
            - <plan query>
            - <group query>
    - full:
        - name: show-plan
          args:
            - <plan query>
    - generic list:
        - name: show-group
          args:
            - <group query>
        - name: show-data
          args:
            - <plan query>
            - <key query>
    - [oneline]:
        - name: show-list
          args:
            - <plan query>
    - tree:
        - name: show-tree
          args:
            - <plan query>
    - boolean:
        - name: status
          side-effects: maybe set status
          args:
            - <plan query>
        - name: member
          args:
            - <plan query>
            - <group query>
    - index:
        - name: advance
          side-effects: shift focus of plan
          args: 
            - <plan query>
            - <index query>
    - hash output:
        - name: hash
          side-effects: <any from hash.sh> 
          args:
            - <hash command>
            - <plan query>
            - <remaining args to hash.sh>
    archive
        archive the plan dir
    import
        pull in previously made archive
          there could be all kinds of merge and shit issues here
          but this is for later

#### TODO move this to hash.sh's files
hash output:
    - hash
    - name
    - ref names
    - group memebership
