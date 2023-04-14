# SwiftAgeVapor Example

This example runs a Vapor web application to show example Apache AGE queries.

Start by creating some person records:

```commandline
% curl "http://127.0.0.1:8080/person"
[]

% curl -X POST -d "name=Paul" "http://127.0.0.1:8080/person"
OK

% curl -X POST -d "name=John" "http://127.0.0.1:8080/person"
OK

% curl -X POST -d "name=George" "http://127.0.0.1:8080/person"
OK

% curl -X POST -d "name=Ringo" "http://127.0.0.1:8080/person"
OK

% curl "http://127.0.0.1:8080/person"
[
  {"id":844424930132020,"name":"Paul"},
  {"id":844424930132021,"name":"John"},
  {"id":844424930132022,"name":"George"},
  {"id":844424930132023,"name":"Ringo"}
]
```
Next, add some relations between persons:
```commandline
% curl "http://127.0.0.1:8080/person/relation" 
[]

% curl -X POST -d "to=844424930132021" "http://127.0.0.1:8080/person/relation/844424930132020"
OK

% curl -X POST -d "to=844424930132022" "http://127.0.0.1:8080/person/relation/844424930132020"
OK

% curl -X POST -d "to=844424930132023" "http://127.0.0.1:8080/person/relation/844424930132020"
OK

% curl "http://127.0.0.1:8080/person/relation"
[
  {"to":{"id":844424930132021,"name":"John"},"relationId":1407374883553289,"from":{"id":844424930132020,"name":"Paul"}},
  {"to":{"id":844424930132022,"name":"George"},"relationId":1407374883553290,"from":{"id":844424930132020,"name":"Paul"}},
  {"to":{"id":844424930132023,"name":"Ringo"},"relationId":1407374883553291,"from":{"id":844424930132020,"name":"Paul"}}
]
```
Delete a relation:
```commandline
% curl -X DELETE "http://127.0.0.1:8080/person/relation/1407374883553289"
OK

% curl "http://127.0.0.1:8080/person/relation"
[
  {"to":{"id":844424930132022,"name":"George"},"relationId":1407374883553290,"from":{"id":844424930132020,"name":"Paul"}},
  {"to":{"id":844424930132023,"name":"Ringo"},"relationId":1407374883553291,"from":{"id":844424930132020,"name":"Paul"}}
]
```
Delete a person which also detaches/deletes their relationship:
```commandline
% curl -X DELETE "http://127.0.0.1:8080/person/844424930132022"
OK

% curl "http://127.0.0.1:8080/person"
[
  {"id":844424930132020,"name":"Paul"},
  {"id":844424930132021,"name":"John"},
  {"id":844424930132023,"name":"Ringo"}
]

% curl "http://127.0.0.1:8080/person/relation"                 
[
  {"to":{"id":844424930132023,"name":"Ringo"},"relationId":1407374883553291,"from":{"id":844424930132020,"name":"Paul"}}
]
```
