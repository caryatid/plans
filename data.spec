data:
    - list
        - name
        - index
        - ordered referencs
    - set
        - name
        - data
        - references
    - assoc
        - name
        - ordered name reference pairs
    - boolean
        - name
        - true|false
    - executable
        - name
        - interpreter
        - source
        
queries:
    - index
        - start
        - end
        - current

input:
    hash-list
output:
    hash-list
    int
    value
    bool

commands:
    null
        - name: sadd
          args:
            target: <hash query>
            source: <hash query>
            key: <key query>
        - name: srem
          args:
            target: <hash query>
            source: <hash query>
            key: <key query>
        - name: lrem
          args:
            target: <hash query>
            source: <hash query>
            key: <key query>
        - name: linsert
          args:
            target: <hash query>
            source: <hash query>
            key: <key query>
            position: <index query>
        - name: remove-non-existent
          args:
            hash: <hash query>
            key: <key query>
        - name: set-interpreter
          args:
            hash: <hash query>
            key: <key query>
    hash-list
        - name: smembers
          args:
            hash: <hash query>
            key: <key query>
        - name: lrange
          args:
            hash: <hash query>
            key: <key query>
            start: <index query>
            stop: <index query>
    int
        - name: scard
          args:
            hash: <hash query>
            key: <key query>
        - name: llen
          args:
            hash: <hash query>
            key: <key query>
        - name: lpos
          args:
            hash: <hash query>
            key: <key query>
            position: <index query>
        - name: lfind
          args:
            target: <hash query>
            source: <hash query>
            key: <key query>
        - name: sfind
          args:
            target: <hash query>
            source: <hash query>
            key: <key query>
    bool
        - name: bool
          args:
            hash: <hash query>
            key: <key query>
            bool: true|false|toggle
    hash
        - name: lindex
          hash: <hash query>
          key: <key query>
          position: <index query>
    value
        - name: execute
          hash: <hash query>
          key: <key query>

