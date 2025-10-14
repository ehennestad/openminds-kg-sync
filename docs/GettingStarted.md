
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

    DefaultServer: PREPROD
     DefaultSpace: "myspace"
```

Run startup to: a) handle authentication (log in to EBRAINS), b) ensure we are using the right version of openMINDS and c) remind us of our preferences.

```matlab
omkg.startup()
```

```matlabTextOutput
Default server: PREPROD
Default space: myspace
```
# Step 2: Create openMINDS Metadata

Let's create some basic neuroscience metadata using openMINDS. We start by creating a **`Person`**:

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
  Person (_:4c8232ea-682a-4238-a1db-8e22d956e382) with properties:

    contactInformation: jane.doe@example.com (ContactInformation)
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
  Organization (_:e5b2b192-dec5-4e6b-a37c-3b9ee4c8235c) with properties:

     fullName: "Example Neuroscience Institute"
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
personId = kgsave(person);
```

```matlabTextOutput
Saved instance "jane.doe@example.com" of type "openminds.core.actors.ContactInformation" to space "myspace" with id "https://kg.ebrains.eu/api/instances/b592b581-60dd-44a3-a965-b4ceb48040fb".
Saved instance "Example Neuroscience Institute" of type "openminds.core.actors.Organization" to space "myspace" with id "https://kg.ebrains.eu/api/instances/ea80db74-88f7-4d88-93fc-b8eca4607e59".
Saved instance "Doe, Jane" of type "openminds.core.actors.Person" to space "myspace" with id "https://kg.ebrains.eu/api/instances/481017f7-153d-4f2e-b4ad-03a20b6e0d5c".
```

```matlab
fprintf('✓ Person saved with ID: %s\n\n', personId);
```

```matlabTextOutput
✓ Person saved with ID: https://kg.ebrains.eu/api/instances/481017f7-153d-4f2e-b4ad-03a20b6e0d5c
```

Notice that linked instances were saved automatically. You can now confirm that these instances were saved in your "myspace" in the [Knowledge Graph Editor](https://editor.kg-ppd.ebrains.eu/browse?space=myspace)!

# Step 4: List and Search Metadata

Let's explore what's already in the Knowledge Graph.

```matlab
[people, nextPage] = kglist("Person", "stage", "IN_PROGRESS"); % Need to use stage="IN_PROGRESS" because metadata is not released yet
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
✓ Found 1 Person instances:
1. Jane Doe (ID: 481017f7-153d-4f2e-b4ad-03a20b6e0d5c)
```
# Step 5: Retrieve Existing Metadata

Now let's retrieve metadata from the Knowledge Graph.

```matlab
instanceId = person.id; % Retrieve person we created before
retrievedInstance = kgpull(instanceId);
disp(retrievedInstance)
```

```matlabTextOutput
  Person (https://kg.ebrains.eu/api/instances/481017f7-153d-4f2e-b4ad-03a20b6e0d5c) with properties:

           affiliation: <reference> (Affiliation)
    contactInformation: <reference> (ContactInformation)
            familyName: "Doe"
             givenName: "Jane"

  Required Properties: givenName
```
# Step 6: Update and Delete Metadata

Finally, let's learn how to update and delete metadata.


**Updating metadata:**

```matlab
contactInfo = person.contactInformation;
contactInfo.email = "jane.doe.updated@example.com";
kgsave(contactInfo)
```

```matlabTextOutput
Updated instance "jane.doe.updated@example.com" of type "openminds.core.actors.ContactInformation".
```

The `kgsave` function automatically detects if an instance already has an ID and updates it rather than creating a new one.


**Deleting metadata:**


Note: Deletion is not recursive, so we need to delete all the instances:

```matlab
% Provide a cell array of instances to delete:
kgdelete( {person, contactInfo, organization} );
```

```matlabTextOutput
Deleted instance of type 'openminds.core.actors.Person' with id: https://kg.ebrains.eu/api/instances/481017f7-153d-4f2e-b4ad-03a20b6e0d5c
Deleted instance of type 'openminds.core.actors.ContactInformation' with id: https://kg.ebrains.eu/api/instances/b592b581-60dd-44a3-a965-b4ceb48040fb
Deleted instance of type 'openminds.core.actors.Organization' with id: https://kg.ebrains.eu/api/instances/ea80db74-88f7-4d88-93fc-b8eca4607e59
```

It is also possible to delete instances one\-by\-one:

```matlab
% kgdelete(person)
% kgdelete(contactInfo)
% kgdelete(organization)
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

