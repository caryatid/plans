# IDEAS 
archive concept can hopefully expand into multiple repository transfer and merge?

features:
    data:
        plans
            represents an achievable and testable goal.
        groups
            basically a hashtag over plans: global groups of plans by name
        generics
            plans used a bit like a pattern or template.
            initializes a plan with a predefined structure and names
        history
            previously referenced plans in order
        references
            arbitrary names to reference a plan
            `open` command sets a special reference
        procedures
            indexed lists of ordered plans stored within a plan
        data
            arbitrary text data by name stored within a plan
            
    queries:
        plan sub query by: 
            ref
                ref query 
            index
                index query 
            parents
                filter by parents
            children
                filter by children
            groups
                filter by group query
            history
                filter by history query
            index
                specify by procedure index
            hash
                pass to hash.sh query
        ref
            reference names regex
        history
            time range, maybe other?
        group
            group names regex
        index shift from:
            beginning
            end
            current position
    commands:
        init-generic 
            creates new tree from a plan; basically a copy but with all new refs.
              it may be difficult for a "plan" to be the source data.
        rm-ref
            removes the reference name ( not the plan )
        ref
            set a plan to a reference name
        open
            opens a plan; setting the special reference name
        show
            plan
                details baby
            group
                oneline display memebers of the group
            data
                dump the data; basically a cat. meow.
            children
                list or tree format with oneline display
        status
            set status
        advance
            move the procedure index
        add
            add plan to another plan's procedure
        remove
            remove plan from another plan's procedure
        move
            move plan from one plan's procedure to another's
        member
            test group memebership of a plan
        group
            add plan to group
        ungroup
            remove plan from group
        archive
            archive the plan dir
        import
            pull in previously made archive
              there could be all kinds of merge and shit issues here
              but this is for later
        hash
            passes through to hash.sh but "lifts" to a plan query 

