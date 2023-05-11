# FHIR_DB

This is the newest iteration of this package. I've started to look into using Dart and a small, lightweight database on the server side, and this prompted some updates. These included adding and adjusting some of the databases that are included. Here's the rundown:

1. [Sembast_SQFLite](https://pub.dev/packages/sembast_sqflite). Still the standard, I think especially if you're going to work with extremely large quantities of data (and need to store it locally on a mobile device), this is still probably your best bet. Also, still want to keep kudos to [Alex Tekartik](https://www.tekartik.com/) for all of his continued work maintaining all of these. I highly recommend that if you have any questions about working with this package that you take a look at [Sembast](https://pub.dev/packages/sembast). He's also just a super nice guy, and even answered a question for me when I was deciding which [sembast version](https://github.com/tekartik/sembast.dart/issues/183) to use.
2. [Sembast](https://pub.dev/packages/sembast) - really the same as the above (follow the link above to see what the difference are). In this case, Sembast can be run in pure Dart, no Flutter necessary.
3. [Hive](https://pub.dev/packages/hive) - Hive has been around a while, but I've finally started looking into it because it's what the [Atsign Folks](https://github.com/atsign-foundation) use as their backend database. So far I like it, and it is really, really fast.
4. Others - Unfortunately I've tried [Isar](https://pub.dev/packages/isar) and [ObjectBox](https://pub.dev/packages/objectbox), and neither of them work particularly well with [Freezed](https://pub.dev/packages/freezed), and the FHIR structure is complicated enough that they have issues with it.
5. [ServerPod](https://pub.dev/packages/serverpod) - I really want to like this, and I'm still hopeful. I'm having issues with serialization, but if they get fixed, I might include it here.

I'm likely going to keep to branches for this repo. One will be for Flutter (so will include the first 3 above), and one will be for dart, which will include Sembast, Hive, and Serverpod (I hope). As always, if you like one of the others that's available and want to try to get it to work, that would be great.

## Functionality and methods needed

1. Create
    - Add new Resource
    - Add a list of Resources

2. Read
    - Active version of a Resource
    - A historical version of a Resource
    - All historical versions of a Resource
    - All versions of a Resource
    - All active versions of a Type of Resource
    - All historical version of a Type of Resource
    - All versions of a Type of Resource
    - All active versions of all Resources
    - All historical versions of all Resources
    - Everything

3. Update
    - Update a Resource (identified by ID)
    - Update a Resource (identified by a Filter/Search)
    - Update multiple Resources (identified by ID)
    - Update multiple Resources (identified by a Filter/Search)

4. Delete
    - Delete a Resource (identified by ID)
    - Delete a Resource (identified by a Filter/Search)
    - Delete multiple Resources (identified by ID)
    - Delete multiple Resources (identified by a Filter/Search)
    - Delete all of a Type of Resource
    - Everything

## Using the Db

So, while not absolutely necessary, I highly recommend that you use some sort of interface class. This adds the benefit of more easily handling errors, plus if you change to a different database in the future, you don't have to change the rest of your app, just the interface.

I've used something like this in my projects:

```dart
class IFhirDb {
  IFhirDb();
  final ResourceDao resourceDao = ResourceDao();

  Future<Either<DbFailure, Resource>> save(Resource resource) async {
    Resource resultResource;
    try {
      resultResource = await resourceDao.save(resource);
    } catch (error) {
      return left(DbFailure.unableToSave(error: error.toString()));
    }
    return right(resultResource);
  }

  Future<Either<DbFailure, List<Resource>>> returnListOfSingleResourceType(
      String resourceType) async {
    List<Resource> resultList;
    try {
      resultList =
          await resourceDao.getAllSortedById(resourceType: resourceType);
    } catch (error) {
      return left(DbFailure.unableToObtainList(error: error.toString()));
    }
    return right(resultList);
  }

  Future<Either<DbFailure, List<Resource>>> searchFunction(
      String resourceType, String searchString, String reference) async {
    List<Resource> resultList;
    try {
      resultList =
          await resourceDao.searchFor(resourceType, searchString, reference);
    } catch (error) {
      return left(DbFailure.unableToObtainList(error: error.toString()));
    }
    return right(resultList);
  }
}
```

I like this because in case there's an i/o error or something, it won't crash your app. Then, you can call this interface in your app like the following:

```dart
final patient = Patient(
    resourceType: 'Patient',
    name: [HumanName(text: 'New Patient Name')],
    birthDate: Date(DateTime.now()),
);

final saveResult = await IFhirDb().save(patient);

```dart
This will save your newly created patient to the locally embedded database.   

*IMPORTANT*: this database will expect that all previously created resources have an id. When you save a resource, it will check to see if that resource type has already been stored. (Each resource type is saved in it's own store in the database). It will then check if there is an ID. If there's no ID, it will create a new one for that resource (along with metadata on version number and creation time). It will save it, and return the resource. If it already has an ID, it will copy the the old version of the resource into a ```_history``` store. It will then update the metadata of the new resource and save that version into the appropriate store for that resource. If, for instance, we have a previously created patient:

```dart
{
    "resourceType": "Patient",
    "id": "fhirfli-294057507-6811107",
    "meta": {
        "versionId": "1",
        "lastUpdated": "2020-10-16T19:41:28.054369Z"
    },
    "name": [
        {
            "given": ["New"],
            "family": "Patient"
        }
    ],
    "birthDate": "2020-10-16"
}
```

And we update the last name to 'Provider'. The above version of the patient will be kept in ```_history```, while in the 'Patient' store in the db, we will have the updated version:

```dart
{
    "resourceType": "Patient",
    "id": "fhirfli-294057507-6811107",
    "meta": {
        "versionId": "2",
        "lastUpdated": "2020-10-16T19:45:07.316698Z"
    },
    "name": [
        {
            "given": ["New"],
            "family": "Provider"
        }
    ],
    "birthDate": "2020-10-16"
}
```

This way we can keep track of all previous version of all resources (which is obviously important in medicine).

For most of the interactions (saving, deleting, etc), they work the way you'd expect. The only difference is search. Because Sembast is NoSQL, we can search on any of the fields in a resource. If in our interface class, we have the following function:

```dart
  Future<Either<DbFailure, List<Resource>>> searchFunction(
      String resourceType, String searchString, String reference) async {
    List<Resource> resultList;
    try {
      resultList =
          await resourceDao.searchFor(resourceType, searchString, reference);
    } catch (error) {
      return left(DbFailure.unableToObtainList(error: error.toString()));
    }
    return right(resultList);
  }
```

You can search for all immunizations of a certain patient:

```dart
searchFunction(
        'Immunization', 'patient.reference', 'Patient/$patientId');
```

This function will search through all entries in the ```'Immunization'``` store. It will look at all ```'patient.reference'``` fields, and return any that match ```'Patient/$patientId'```.

The last thing I'll mention is that this is a password protected db, using AES-256 encryption (although it can also use Salsa20). Anytime you use the db, you have the option of using a password for encryption/decryption. Remember, if you setup the database using encryption, you will only be able to access it using that same password. When you're ready to change the password, you will need to call the update password function. If we again assume we created a change password method in our interface, it might look something like this:

```dart
class IFhirDb {
  IFhirDb();
  final ResourceDao resourceDao = ResourceDao();
  ...
    Future<Either<DbFailure, Unit>> updatePassword(String oldPassword, String newPassword) async {
    try {
      await resourceDao.updatePw(oldPassword, newPassword);
    } catch (error) {
      return left(DbFailure.unableToUpdatePassword(error: error.toString()));
    }
    return right(Unit);
  }
```

You don't have to use a password, and in that case, it will save the db file as plain text. If you want to add a password later, it will encrypt it at that time.

### General Store

After using this for a while in an app, I've realized that it needs to be able to store data apart from just FHIR resources, at least on occasion. For this, I've added a second class for all versions of the database called GeneralDao. This is similar to the ResourceDao, but fewer options. So, in order to save something, it would look like this:

```dart
await GeneralDao().save('password', {'new':'map'});
await GeneralDao().save('password', {'new':'map'}, 'key');
```

The difference between these two options is that the first one will generate a key for the map being stored, while the second will store the map using the key provided. Both will return the key after successfully storing the map.

Other functions available include:

```dart
// deletes everything in the general store
await GeneralDao().deleteAllGeneral('password'); 

// delete specific entry
await GeneralDao().delete('password','key'); 

// returns map with that key
await GeneralDao().find('password', 'key'); 
```

FHIR® is a registered trademark of Health Level Seven International (HL7) and its use does not constitute an endorsement of products by HL7®
