
# Welcome to openMINDS\-KnowledgeGraph\-Sync Toolbox

This tutorial will guide you through the essential steps of working with the EBRAINS Knowledge Graph using openMINDS metadata standards. You'll learn to create, save, retrieve, and manage neuroscience metadata.


**What you'll learn:**

1.  Setting up your environment and authentication
2. Creating openMINDS metadata instances
3. Saving metadata to the Knowledge Graph
4. Listing and searching existing instances
5. Retrieving and working with existing metadata
6. Managing your metadata (updating and deleting)

**Prerequisites:**

-  MATLAB R2019b or later 
-  openMINDS and EBRAINS\-MATLAB toolboxes installed 
-  EBRAINS account and authentication setup 
# Step 1: Prepare Environment

First, let's ensure that the environment is properly configured:

```matlab
prefs = omkg.setpref('DefaultSpace', 'myspace'); % Ensure we save into our own space
disp(prefs)
```

```matlabTextOutput
Preferences for the OpenMINDS-KG-Sync Toolbox:

    DefaultServer: PROD
     DefaultSpace: "myspace"
```

Run startup. This will a) handle authentication (log in to EBRAINS), b) ensure we are using the right version of openMINDS and c) remind us of our preferences.

```matlab
omkg.startup()
```

```matlabTextOutput
Default server: PROD
Default space: myspace
```
# Step 2: Create openMINDS Metadata

Let's create some basic neuroscience metadata using openMINDS. We start by creating a **`Person`**

```matlab
% Person is part of the openMINDS core module
person = openminds.core.Person();
person.givenName = "Jane";
person.familyName = "Doe";

% We can also add an email. This must go in the ContactInformation type:
person.contactInformation = openminds.core.ContactInformation("email", "jane.doe@example.com");

disp(person) % Display the Person instance
```

```matlabTextOutput
  Person (_:77756fff-ec0f-49ad-885f-0c911e8eb4a1) with properties:

           affiliation: [1x0 Affiliation] (Affiliation)
         alternateName: [1x0 string]
     associatedAccount: [1x0 AccountInformation] (AccountInformation)
    contactInformation: jane.doe@example.com (ContactInformation)
     digitalIdentifier: [1x0 ORCID] (ORCID)
            familyName: "Doe"
             givenName: "Jane"

  Required Properties: givenName
```

Next we create an **`Organization`** which the **`Person`** is affiliated with:

```matlab
% We can also create instances providing values using name-value pairs:
organization = openminds.core.Organization(...
    "fullName", "Example Neuroscience Institute", ...
    "shortName", "ENI");
disp(organization) % Display the Organization instance
```

```matlabTextOutput
  Organization (_:82ad5787-f4f5-4527-bdb4-97f1532e7542) with properties:

          affiliation: [1x0 Affiliation] (Affiliation)
    digitalIdentifier: [1x0 DigitalIdentifier] (Any of: GRIDID, RORID, RRID )
             fullName: "Example Neuroscience Institute"
            hasParent: [1x0 Organization] (Organization)
             homepage: ""
            shortName: "ENI"

  Required Properties: fullName
```

Link them together using the **`Affiliation`** type:

```matlab
affiliation = openminds.core.Affiliation(...
    "memberOf", organization);
    
person.affiliation = affiliation;
```
# Step 3: Save to Knowledge Graph

Now let's save our metadata to the EBRAINS Knowledge Graph.

```matlab
personId = kgsave(person); %TODO: retrieve the identifier
```

```matlabTextOutput
Saved instance "jane.doe@example.com" of type "openminds.core.actors.ContactInformation" to space "myspace".
Saved instance "Example Neuroscience Institute" of type "openminds.core.actors.Organization" to space "myspace".
Saved instance "Doe, Jane" of type "openminds.core.actors.Person" to space "myspace".
```

```matlab
fprintf('✓ Person saved with ID: %s\n\n', personId);
```

```matlabTextOutput
✓ Person saved with ID: 
```

Notice that linked instances were saved automatically. You can now confirm that these instances were saved in you "myspace" in the [Knowledge Graph Editor](https://editor.kg.ebrains.eu/browse?space=myspace)!

# Step 4: List and Search Metadata

Let's explore what's already in the Knowledge Graph.

```matlab
[people, nextPage] = kglist("Person");
% Print names of people that were found
if ~isempty(people)
    fprintf('✓ Found %d Person instances:\n', length(people));
    for i = 1:min(3, length(people))  % Show first 3
        if ~isempty(people(i).givenName) && ~isempty(people(i).familyName)
            fprintf('  %d. %s %s (ID: %s)\n', i, ...
                people(i).givenName, people(i).familyName, ...
                extractAfter(people(i).id, "instances/"));
        end
    end
    if length(people) > 3
        fprintf('  ... and %d more\n', length(people) - 3);
    end
else
    fprintf('No Person instances found in current space.\n');
end
```

```matlabTextOutput
✓ Found 2 Person instances:
1. Jane Doe (ID: 2d65e694-b7e6-445f-b49f-02723e476e74)
  2. Jane Doe (ID: 997dc90f-d3d7-4b21-b643-2002d35f7c2e)
```
# Step 5: Retrieve Existing Metadata

Now let's retrieve metadata from the Knowledge Graph.

```matlab
instanceId = person.id; % Retrieve person we created before
retrievedInstance = kgpull(instanceId);
disp(retrievedInstance)
```

```matlabTextOutput
  Person (https://kg.ebrains.eu/api/instances/2d65e694-b7e6-445f-b49f-02723e476e74) with properties:

           affiliation: <external reference> (Affiliation)
         alternateName: [1x0 string]
     associatedAccount: [1x0 AccountInformation] (AccountInformation)
    contactInformation: <reference> (ContactInformation)
     digitalIdentifier: [1x0 ORCID] (ORCID)
            familyName: "Doe"
             givenName: "Jane"

  Required Properties: givenName
```
# Step 6: Update and Delete Metadata

Finally, let's learn how to update and delete metadata.


**Updating metadata:**

```matlab
contactInfo = person.contactInformation;
contactInfo.email = "jane.doe.updated@example.com"
```

```matlabTextOutput
contactInfo = 
  ContactInformation (https://kg.ebrains.eu/api/instances/b925574a-978d-4a98-9dc2-1ef60ddf0949) with properties:

    email: "jane.doe.updated@example.com"

  Required Properties: email

```

```matlab
kgsave(contactInfo)
```

The `kgsave` function automatically detects if an instance already has an ID and updates it rather than creating a new one.


**Deleting metadata:**


Note: Deletion is not recursive, so we need to delete instances one\-by\-one:

```matlab
kgdelete(person)
```

```matlabTextOutput
Deleted instance of type 'openminds.core.actors.Person' with id: https://kg.ebrains.eu/api/instances/2d65e694-b7e6-445f-b49f-02723e476e74
```

```matlab
kgdelete(contactInfo)
```

```matlabTextOutput
Deleted instance of type 'openminds.core.actors.ContactInformation' with id: https://kg.ebrains.eu/api/instances/b925574a-978d-4a98-9dc2-1ef60ddf0949
```

```matlab
kgdelete(organization)
```

```matlabTextOutput
Deleted instance of type 'openminds.core.actors.Organization' with id: https://kg.ebrains.eu/api/instances/49495bce-0ee8-426b-8209-68a28d75828f
```

```matlab

% Alternatively, provide a cell array of instances :
% kgdelete( {person, contactInfo, organization} );
```

Important: Deletion is permanent! Always double\-check before deleting.

# Tutorial Complete

 Congratulations! You've learned the basics of openMINDS KG Sync.


What you've accomplished:


✓ Set up your environment


✓ Created openMINDS metadata instances


✓ Saved metadata to the Knowledge Graph


✓ Listed and searched existing metadata


✓ Retrieved metadata with link resolution


✓ Learned about updating and deleting

