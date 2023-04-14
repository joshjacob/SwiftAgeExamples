# SwiftAgeMacOS Example

This example compiles to a macOS command line app to show example Apache AGE queries:

```commandline
Welcome to the SwiftAge command line tester!

Next command:
help
  Commands:
    list - list all 'Person' vertexes in the graph
    add  - add 'Person' vertex
    del  - delete 'Person' vertex
    list_rel - list all 'Person' to 'Person' relations
    add_rel - add a 'Person' to 'Person' relation
    del_rel - delete a 'Person' to 'Person' relation
    quit - say goodbye

Next command:
list
No people present.

Next command:
add
Enter person's name:
Paul
Person added.

Next command:
add
Enter person's name:
John
Person added.

Next command:
add
Enter person's name:
George
Person added.

Next command:
add
Enter person's name:
Ringo
Person added.

Next command:
list
Found person with name Paul (id = 844424930132015)
Found person with name John (id = 844424930132016)
Found person with name George (id = 844424930132017)
Found person with name Ringo (id = 844424930132018)

Next command:
add_rel
Enter person 1's id:
844424930132015
Enter person 2's id:
844424930132016
Relation added.

Next command:
list_rel
Found Paul related to John with relation id 1407374883553286

Next command:
add_rel
Enter person 1's id:
844424930132015
Enter person 2's id:
844424930132017
Relation added.

Next command:
list_rel
Found Paul related to John with relation id 1407374883553286
Found Paul related to George with relation id 1407374883553287

Next command:
del_rel
Enter relation id:
1407374883553286
Relation removed.

Next command:
list_rel
Found Paul related to George with relation id 1407374883553287

Next command:
del
Enter person's id:
844424930132016
Person deleted.

Next command:
list
Found person with name Paul (id = 844424930132015)
Found person with name George (id = 844424930132017)
Found person with name Ringo (id = 844424930132018)

Next command:
quit
Goodbye!
```
