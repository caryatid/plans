
data:
    - hash
        - id
        - [key]
    - key
        - name # no spaces
        - value

queries:
    - hash:
        - key-match:
            - key-pattern
            - value-pattern
        - new
            - key
            - value
        - singleton
            - key
            - value
        - no-parse
            - hash
        - hash-prefix
    - key:
        - singleton
            - key
        - key-pattern
        - key-prefx

output:
    parse-fail: hash-list
    hash-list:
        - hash
        - append-data
    hash: sha1
    value: anything that can go in a file

input:
    value: anything that can go in a file
    hash-list: same as hash-list output

commands:
    null:
        - name: delete
          args: <hash query>
          side-effects: delete the hash entry
        - name: delete-key
          args:
            - <hash query>
            - <key query>
          side-effects: delete the key entry
        - name:set-key
          stdin: value
          args:
            - <hash query>
            - <key query>
          side-effects: key set to stdin value
        - name: edit-key
          args:
            - <hash query>
            - <key query>
          side-effects: opens key in an editor; sets value on save
    hash-list:
        - name: list-hashes
        - name: append
          args:
            - <value query>
            - width 
    hash:
        - name: id
          args: <hash query>
    value:
        - name: get-key
          args: 
            - <hash query>
            - <key query>
