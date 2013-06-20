@startuml
hide members

OResource <|-- OComponent
OResource <|-- OGroup
OGroup <|-- Account
OResource <|-- Lease
OResource <|-- OProject
OResource <|-- User
@enduml

@startuml
hide members

OGroup "*" -- "*" OComponent : contains >
OGroup "1" -- "*" OGroup : contains >
OComponent "*" -- "1" Account : charged_to >
OComponent "1" -- "*" OComponent : provided_by >
Lease "*" -- "0,1" OComponent: < leased_by 
OProject "1" -- "1" Account : account >
OProject "*" -- "*" User: member > 
Account "*" -- "1" Lease : holds_lease >
OProject "*" -- "1" OProject: parent_project > 
@enduml