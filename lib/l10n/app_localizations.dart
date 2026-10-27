import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get navGroups;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @gateGroupSwipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to swipe together with a group'**
  String get gateGroupSwipeTitle;

  /// No description provided for @gateGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to create or join a group'**
  String get gateGroupsTitle;

  /// No description provided for @gateJoinGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to join this group'**
  String get gateJoinGroupTitle;

  /// No description provided for @gateGroupMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to see your group matches'**
  String get gateGroupMatchesTitle;

  /// No description provided for @gateProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to set up your profile'**
  String get gateProfileTitle;

  /// No description provided for @gateFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to keep your favorites'**
  String get gateFavoritesTitle;

  /// No description provided for @gateBody.
  ///
  /// In en, this message translates to:
  /// **'It only takes a minute, and the places you liked as a guest come with you.'**
  String get gateBody;

  /// No description provided for @gateCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get gateCreateAccount;

  /// No description provided for @gateHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get gateHaveAccount;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name / username'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'What should others call you?'**
  String get nameHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get nameRequired;

  /// No description provided for @nameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameTooShort;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @noAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get noAccountRegister;

  /// No description provided for @haveAccountLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get haveAccountLogin;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue without an account'**
  String get continueAsGuest;

  /// No description provided for @authUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email'**
  String get authUserNotFound;

  /// No description provided for @authWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get authWrongPassword;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get authInvalidEmail;

  /// No description provided for @authUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled'**
  String get authUserDisabled;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authTooManyRequests;

  /// No description provided for @authNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your internet connection.'**
  String get authNetwork;

  /// No description provided for @authInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get authInvalidCredential;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-up failed. Please try again.'**
  String get signupFailed;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errorPermissionDenied;

  /// No description provided for @errorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection. Please check your internet and try again.'**
  String get errorNoConnection;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists.'**
  String get errorNotFound;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Please log in instead.'**
  String get errorEmailInUse;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password.'**
  String get errorWeakPassword;

  /// No description provided for @errorGroupNotFound.
  ///
  /// In en, this message translates to:
  /// **'Group not found.'**
  String get errorGroupNotFound;

  /// No description provided for @errorInvalidInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite code.'**
  String get errorInvalidInviteCode;

  /// No description provided for @errorJoiningDisabled.
  ///
  /// In en, this message translates to:
  /// **'Joining is currently disabled for this group.'**
  String get errorJoiningDisabled;

  /// No description provided for @errorAdminOnlyStart.
  ///
  /// In en, this message translates to:
  /// **'Only the admin can start the session.'**
  String get errorAdminOnlyStart;

  /// No description provided for @errorAdminOnlyEnd.
  ///
  /// In en, this message translates to:
  /// **'Only the admin can end the session.'**
  String get errorAdminOnlyEnd;

  /// No description provided for @errorAdminOnlyReorder.
  ///
  /// In en, this message translates to:
  /// **'Only the admin can reorder the list.'**
  String get errorAdminOnlyReorder;

  /// No description provided for @errorNoPlacesForDestination.
  ///
  /// In en, this message translates to:
  /// **'No places found for this destination.'**
  String get errorNoPlacesForDestination;

  /// No description provided for @errorGroupLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Set a group location before starting a session.'**
  String get errorGroupLocationRequired;

  /// No description provided for @errorSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'This session no longer exists.'**
  String get errorSessionNotFound;

  /// No description provided for @errorNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Please log in and try again.'**
  String get errorNotLoggedIn;

  /// No description provided for @errorLoadPlaces.
  ///
  /// In en, this message translates to:
  /// **'Could not load places.'**
  String get errorLoadPlaces;

  /// No description provided for @errorLoadFavorites.
  ///
  /// In en, this message translates to:
  /// **'Could not load your favorites.'**
  String get errorLoadFavorites;

  /// No description provided for @errorLoadPlace.
  ///
  /// In en, this message translates to:
  /// **'Could not load this place.'**
  String get errorLoadPlace;

  /// No description provided for @errorOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Maps app.'**
  String get errorOpenMaps;

  /// No description provided for @errorLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile.'**
  String get errorLoadProfile;

  /// No description provided for @errorUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile.'**
  String get errorUpdateProfile;

  /// No description provided for @errorLoadAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account.'**
  String get errorLoadAccount;

  /// No description provided for @errorLoadGroups.
  ///
  /// In en, this message translates to:
  /// **'Could not load your groups.'**
  String get errorLoadGroups;

  /// No description provided for @errorCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Could not create the group.'**
  String get errorCreateGroup;

  /// No description provided for @errorStartSession.
  ///
  /// In en, this message translates to:
  /// **'Could not start the session.'**
  String get errorStartSession;

  /// No description provided for @errorJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Could not join the group.'**
  String get errorJoinGroup;

  /// No description provided for @errorDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the group.'**
  String get errorDeleteGroup;

  /// No description provided for @errorLoadSessions.
  ///
  /// In en, this message translates to:
  /// **'Could not load past sessions.'**
  String get errorLoadSessions;

  /// No description provided for @errorLoadResults.
  ///
  /// In en, this message translates to:
  /// **'Could not load results.'**
  String get errorLoadResults;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Places'**
  String get discoverTitle;

  /// No description provided for @errorLoadingPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Error loading places'**
  String get errorLoadingPlacesTitle;

  /// No description provided for @noMorePlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'No more places!'**
  String get noMorePlacesTitle;

  /// No description provided for @seenAllPlaces.
  ///
  /// In en, this message translates to:
  /// **'You have seen all places'**
  String get seenAllPlaces;

  /// No description provided for @guestLikeHint.
  ///
  /// In en, this message translates to:
  /// **'Saved! Create an account to keep your favorites for good.'**
  String get guestLikeHint;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites!'**
  String get addedToFavorites;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @likeStamp.
  ///
  /// In en, this message translates to:
  /// **'LIKE'**
  String get likeStamp;

  /// No description provided for @nopeStamp.
  ///
  /// In en, this message translates to:
  /// **'NOPE'**
  String get nopeStamp;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Favorites'**
  String get favoritesTitle;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @clearFavoritesMenu.
  ///
  /// In en, this message translates to:
  /// **'Clear favorites & swipe history'**
  String get clearFavoritesMenu;

  /// No description provided for @removeFromFavoritesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavoritesTooltip;

  /// No description provided for @placeRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'{name} removed from favorites'**
  String placeRemovedFromFavorites(String name);

  /// No description provided for @placeAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'{name} added to favorites!'**
  String placeAddedToFavorites(String name);

  /// No description provided for @clearEverythingTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear everything?'**
  String get clearEverythingTitle;

  /// No description provided for @clearEverythingBody.
  ///
  /// In en, this message translates to:
  /// **'This removes all your favorites and your swipe history, so places you already swiped will show up again. This cannot be undone.'**
  String get clearEverythingBody;

  /// No description provided for @clearedSnack.
  ///
  /// In en, this message translates to:
  /// **'Favorites and swipe history cleared'**
  String get clearedSnack;

  /// No description provided for @noFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesTitle;

  /// No description provided for @noFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Start swiping to add places to your favorites!'**
  String get noFavoritesBody;

  /// No description provided for @endSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'End session?'**
  String get endSessionTitle;

  /// No description provided for @endSessionBody.
  ///
  /// In en, this message translates to:
  /// **'This will end the session for all participants.'**
  String get endSessionBody;

  /// No description provided for @endSession.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get endSession;

  /// No description provided for @timeIsUp.
  ///
  /// In en, this message translates to:
  /// **'Time is up!'**
  String get timeIsUp;

  /// No description provided for @waitingForSessionEnd.
  ///
  /// In en, this message translates to:
  /// **'Waiting for session to end...'**
  String get waitingForSessionEnd;

  /// No description provided for @viewedAllPlaces.
  ///
  /// In en, this message translates to:
  /// **'You have viewed all places'**
  String get viewedAllPlaces;

  /// No description provided for @liked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get liked;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @placeFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeFallbackTitle;

  /// No description provided for @placeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Place not found'**
  String get placeNotFound;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @coordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// No description provided for @openInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get openInMaps;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get removeFromFavorites;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get addToFavorites;

  /// No description provided for @groupResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Results'**
  String get groupResultsTitle;

  /// No description provided for @failedToLoadGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to load group'**
  String get failedToLoadGroup;

  /// No description provided for @noGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'No Group'**
  String get noGroupTitle;

  /// No description provided for @noGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Create or join a group first'**
  String get noGroupMessage;

  /// No description provided for @noCompletedSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Completed Sessions'**
  String get noCompletedSessionsTitle;

  /// No description provided for @noCompletedSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'Finish a session to see results here.'**
  String get noCompletedSessionsBody;

  /// No description provided for @noQualifiedPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Qualified Places'**
  String get noQualifiedPlacesTitle;

  /// No description provided for @noQualifiedPlacesBody.
  ///
  /// In en, this message translates to:
  /// **'Places need enough likes to appear here.'**
  String get noQualifiedPlacesBody;

  /// No description provided for @sessionInProgress.
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get sessionInProgress;

  /// No description provided for @groupDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Details'**
  String get groupDetailsTitle;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @loginToUseGroups.
  ///
  /// In en, this message translates to:
  /// **'Please login to use groups'**
  String get loginToUseGroups;

  /// No description provided for @groupNotFound.
  ///
  /// In en, this message translates to:
  /// **'Group not found'**
  String get groupNotFound;

  /// No description provided for @newGroupButton.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newGroupButton;

  /// No description provided for @statusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get statusLive;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get statusStart;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @unnamedGroup.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Group'**
  String get unnamedGroup;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String memberCount(int count);

  /// No description provided for @noGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Groups Yet'**
  String get noGroupsTitle;

  /// No description provided for @noGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Create a new group or join an existing one'**
  String get noGroupsBody;

  /// No description provided for @createNewGroup.
  ///
  /// In en, this message translates to:
  /// **'Create New Group'**
  String get createNewGroup;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get groupNameHint;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @groupLocation.
  ///
  /// In en, this message translates to:
  /// **'Location: {city}, {country}'**
  String groupLocation(String city, String country);

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code: {code}'**
  String inviteCode(String code);

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied to clipboard'**
  String get inviteCodeCopied;

  /// No description provided for @joiningDisabled.
  ///
  /// In en, this message translates to:
  /// **'Joining is disabled (Session active)'**
  String get joiningDisabled;

  /// No description provided for @waitingForAdmin.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the admin to start a session.'**
  String get waitingForAdmin;

  /// No description provided for @adminControls.
  ///
  /// In en, this message translates to:
  /// **'Admin Controls'**
  String get adminControls;

  /// No description provided for @limitType.
  ///
  /// In en, this message translates to:
  /// **'Limit Type: '**
  String get limitType;

  /// No description provided for @limitSwipes.
  ///
  /// In en, this message translates to:
  /// **'Swipes'**
  String get limitSwipes;

  /// No description provided for @limitTime.
  ///
  /// In en, this message translates to:
  /// **'Time (mins)'**
  String get limitTime;

  /// No description provided for @timeLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Time Limit: '**
  String get timeLimitLabel;

  /// No description provided for @swipeLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Swipe Limit: '**
  String get swipeLimitLabel;

  /// No description provided for @minutesSuffix.
  ///
  /// In en, this message translates to:
  /// **'mins'**
  String get minutesSuffix;

  /// No description provided for @startSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get startSession;

  /// No description provided for @endSessionEarly.
  ///
  /// In en, this message translates to:
  /// **'End Session Early'**
  String get endSessionEarly;

  /// No description provided for @membersHeader.
  ///
  /// In en, this message translates to:
  /// **'Members ({count})'**
  String membersHeader(int count);

  /// No description provided for @memberFallback.
  ///
  /// In en, this message translates to:
  /// **'Member {number}'**
  String memberFallback(int number);

  /// No description provided for @memberYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String memberYou(String name);

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @continueSwiping.
  ///
  /// In en, this message translates to:
  /// **'Continue Swiping'**
  String get continueSwiping;

  /// No description provided for @viewMatches.
  ///
  /// In en, this message translates to:
  /// **'View Matches'**
  String get viewMatches;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leaveGroup;

  /// No description provided for @enterNameAndLocation.
  ///
  /// In en, this message translates to:
  /// **'Please enter name and select location'**
  String get enterNameAndLocation;

  /// No description provided for @groupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created successfully!'**
  String get groupCreated;

  /// No description provided for @timeLimitRange.
  ///
  /// In en, this message translates to:
  /// **'Time limit must be between 1 and 120 mins'**
  String get timeLimitRange;

  /// No description provided for @swipeLimitRange.
  ///
  /// In en, this message translates to:
  /// **'Swipe limit must be between 1 and 100'**
  String get swipeLimitRange;

  /// No description provided for @sessionStarted.
  ///
  /// In en, this message translates to:
  /// **'Session started!'**
  String get sessionStarted;

  /// No description provided for @joinGroupViaInvite.
  ///
  /// In en, this message translates to:
  /// **'Join Group via Invite'**
  String get joinGroupViaInvite;

  /// No description provided for @inviteCodeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite Code (6 chars)'**
  String get inviteCodeFieldLabel;

  /// No description provided for @enterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter an Invite Code'**
  String get enterInviteCode;

  /// No description provided for @joinedGroup.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined group!'**
  String get joinedGroup;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Group?'**
  String get leaveGroupTitle;

  /// No description provided for @leaveGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group?'**
  String get leaveGroupBody;

  /// No description provided for @leftGroup.
  ///
  /// In en, this message translates to:
  /// **'Left group'**
  String get leftGroup;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \'{name}\'? This cannot be undone.'**
  String deleteGroupBody(String name);

  /// No description provided for @joinedViaLink.
  ///
  /// In en, this message translates to:
  /// **'Joined group via link!'**
  String get joinedViaLink;

  /// No description provided for @joiningGroup.
  ///
  /// In en, this message translates to:
  /// **'Joining Group...'**
  String get joiningGroup;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @loginToViewProfile.
  ///
  /// In en, this message translates to:
  /// **'Please login to view your profile'**
  String get loginToViewProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @accountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get accountInfo;

  /// No description provided for @noEmail.
  ///
  /// In en, this message translates to:
  /// **'No email provided'**
  String get noEmail;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated!'**
  String get profileUpdated;

  /// No description provided for @userFallbackName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallbackName;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppSection.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsAppSection;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your data is used'**
  String get privacySubtitle;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @securitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your account is protected'**
  String get securitySubtitle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out on this device'**
  String get logoutSubtitle;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to log out?'**
  String get logoutConfirm;

  /// No description provided for @privacyWhatWeStore.
  ///
  /// In en, this message translates to:
  /// **'What we store'**
  String get privacyWhatWeStore;

  /// No description provided for @privacyItemEmail.
  ///
  /// In en, this message translates to:
  /// **'• Email address (for sign-in)'**
  String get privacyItemEmail;

  /// No description provided for @privacyItemProfile.
  ///
  /// In en, this message translates to:
  /// **'• Display name and profile picture'**
  String get privacyItemProfile;

  /// No description provided for @privacyItemActivity.
  ///
  /// In en, this message translates to:
  /// **'• Favorites, swipes and group memberships'**
  String get privacyItemActivity;

  /// No description provided for @privacyItemLocation.
  ///
  /// In en, this message translates to:
  /// **'• Your location, only while finding nearby places'**
  String get privacyItemLocation;

  /// No description provided for @privacyWhereStored.
  ///
  /// In en, this message translates to:
  /// **'Where it is stored'**
  String get privacyWhereStored;

  /// No description provided for @privacyWhereStoredBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored with Google Firebase. Place information and photos come from Google Maps Platform. Members of your groups can see your display name.'**
  String get privacyWhereStoredBody;

  /// No description provided for @privacyRights.
  ///
  /// In en, this message translates to:
  /// **'Your rights'**
  String get privacyRights;

  /// No description provided for @privacyRightsBody.
  ///
  /// In en, this message translates to:
  /// **'You can ask to see, correct or delete your data at any time.'**
  String get privacyRightsBody;

  /// No description provided for @securityHeader.
  ///
  /// In en, this message translates to:
  /// **'How your account is protected'**
  String get securityHeader;

  /// No description provided for @securityItemAuth.
  ///
  /// In en, this message translates to:
  /// **'✓ Sign-in handled by Firebase Authentication'**
  String get securityItemAuth;

  /// No description provided for @securityItemHttps.
  ///
  /// In en, this message translates to:
  /// **'✓ All data is sent over encrypted connections (HTTPS)'**
  String get securityItemHttps;

  /// No description provided for @securityTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get securityTips;

  /// No description provided for @securityTipPassword.
  ///
  /// In en, this message translates to:
  /// **'• Use a strong, unique password'**
  String get securityTipPassword;

  /// No description provided for @securityTipLogout.
  ///
  /// In en, this message translates to:
  /// **'• Log out on shared devices'**
  String get securityTipLogout;

  /// No description provided for @securityTipUpdate.
  ///
  /// In en, this message translates to:
  /// **'• Keep the app up to date'**
  String get securityTipUpdate;

  /// No description provided for @securityComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Changing your password and two-factor authentication are coming in a future version.'**
  String get securityComingSoon;

  /// No description provided for @createAccountToManage.
  ///
  /// In en, this message translates to:
  /// **'Create an account to manage your profile and log in on other devices.'**
  String get createAccountToManage;

  /// No description provided for @tagTouristAttraction.
  ///
  /// In en, this message translates to:
  /// **'Sight'**
  String get tagTouristAttraction;

  /// No description provided for @tagMuseum.
  ///
  /// In en, this message translates to:
  /// **'Museum'**
  String get tagMuseum;

  /// No description provided for @tagArtGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get tagArtGallery;

  /// No description provided for @tagArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get tagArt;

  /// No description provided for @tagCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get tagCulture;

  /// No description provided for @tagHistoricalLandmark.
  ///
  /// In en, this message translates to:
  /// **'Historic site'**
  String get tagHistoricalLandmark;

  /// No description provided for @tagCulturalLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get tagCulturalLandmark;

  /// No description provided for @tagLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get tagLandmark;

  /// No description provided for @tagHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tagHistory;

  /// No description provided for @tagChurch.
  ///
  /// In en, this message translates to:
  /// **'Church'**
  String get tagChurch;

  /// No description provided for @tagPark.
  ///
  /// In en, this message translates to:
  /// **'Park'**
  String get tagPark;

  /// No description provided for @tagGarden.
  ///
  /// In en, this message translates to:
  /// **'Garden'**
  String get tagGarden;

  /// No description provided for @tagMonument.
  ///
  /// In en, this message translates to:
  /// **'Monument'**
  String get tagMonument;

  /// No description provided for @tagNationalPark.
  ///
  /// In en, this message translates to:
  /// **'National park'**
  String get tagNationalPark;

  /// No description provided for @tagObservationDeck.
  ///
  /// In en, this message translates to:
  /// **'Observation deck'**
  String get tagObservationDeck;

  /// No description provided for @tagTheater.
  ///
  /// In en, this message translates to:
  /// **'Theatre'**
  String get tagTheater;

  /// No description provided for @tagPlayground.
  ///
  /// In en, this message translates to:
  /// **'Playground'**
  String get tagPlayground;

  /// No description provided for @tagShoppingMall.
  ///
  /// In en, this message translates to:
  /// **'Shopping mall'**
  String get tagShoppingMall;

  /// No description provided for @tagNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get tagNature;

  /// No description provided for @tagNaturalFeature.
  ///
  /// In en, this message translates to:
  /// **'Nature spot'**
  String get tagNaturalFeature;

  /// No description provided for @tagOutdoors.
  ///
  /// In en, this message translates to:
  /// **'Outdoors'**
  String get tagOutdoors;

  /// No description provided for @tagBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get tagBeach;

  /// No description provided for @tagViewpoint.
  ///
  /// In en, this message translates to:
  /// **'Viewpoint'**
  String get tagViewpoint;

  /// No description provided for @tagHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get tagHiking;

  /// No description provided for @tagFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get tagFamily;

  /// No description provided for @tagScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get tagScience;

  /// No description provided for @tagZoo.
  ///
  /// In en, this message translates to:
  /// **'Zoo'**
  String get tagZoo;

  /// No description provided for @tagAquarium.
  ///
  /// In en, this message translates to:
  /// **'Aquarium'**
  String get tagAquarium;

  /// No description provided for @tagAmusementPark.
  ///
  /// In en, this message translates to:
  /// **'Theme park'**
  String get tagAmusementPark;

  /// No description provided for @tagShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get tagShopping;

  /// No description provided for @tagMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get tagMarket;

  /// No description provided for @tagNightlife.
  ///
  /// In en, this message translates to:
  /// **'Nightlife'**
  String get tagNightlife;

  /// No description provided for @tagMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get tagMusic;

  /// No description provided for @tagArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get tagArchitecture;

  /// No description provided for @tagPhotoSpot.
  ///
  /// In en, this message translates to:
  /// **'Photo spot'**
  String get tagPhotoSpot;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo last swipe'**
  String get undo;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @undone.
  ///
  /// In en, this message translates to:
  /// **'Brought back'**
  String get undone;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @sessionLive.
  ///
  /// In en, this message translates to:
  /// **'Session in progress'**
  String get sessionLive;

  /// No description provided for @sessionTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left'**
  String sessionTimeLeft(int minutes);

  /// No description provided for @yourProgress.
  ///
  /// In en, this message translates to:
  /// **'your progress'**
  String get yourProgress;

  /// No description provided for @memberDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get memberDone;

  /// No description provided for @whoIsSwiping.
  ///
  /// In en, this message translates to:
  /// **'Who\'s still swiping?'**
  String get whoIsSwiping;

  /// No description provided for @matchTitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s a match!'**
  String get matchTitle;

  /// No description provided for @matchBody.
  ///
  /// In en, this message translates to:
  /// **'{place} made your list.'**
  String matchBody(String place);

  /// No description provided for @matchVotes.
  ///
  /// In en, this message translates to:
  /// **'{likes} of {total} likes'**
  String matchVotes(int likes, int total);

  /// No description provided for @matchSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See all results'**
  String get matchSeeResults;

  /// No description provided for @matchOpenPlace.
  ///
  /// In en, this message translates to:
  /// **'View place'**
  String get matchOpenPlace;

  /// No description provided for @onboarding1Lead.
  ///
  /// In en, this message translates to:
  /// **'Swipe your way to your'**
  String get onboarding1Lead;

  /// No description provided for @onboarding1Accent.
  ///
  /// In en, this message translates to:
  /// **'next favourite place.'**
  String get onboarding1Accent;

  /// No description provided for @onboarding1Body.
  ///
  /// In en, this message translates to:
  /// **'Swipe right for “want to see”, left for “rather not”.'**
  String get onboarding1Body;

  /// No description provided for @onboarding2Lead.
  ///
  /// In en, this message translates to:
  /// **'Save what you love,'**
  String get onboarding2Lead;

  /// No description provided for @onboarding2Accent.
  ///
  /// In en, this message translates to:
  /// **'plan it later.'**
  String get onboarding2Accent;

  /// No description provided for @onboarding2Body.
  ///
  /// In en, this message translates to:
  /// **'Every like lands in your favorites, ready for your next trip.'**
  String get onboarding2Body;

  /// No description provided for @onboarding3Lead.
  ///
  /// In en, this message translates to:
  /// **'Plan together,'**
  String get onboarding3Lead;

  /// No description provided for @onboarding3Accent.
  ///
  /// In en, this message translates to:
  /// **'without endless chats.'**
  String get onboarding3Accent;

  /// No description provided for @onboarding3Body.
  ///
  /// In en, this message translates to:
  /// **'Everyone swipes the same deck. TripFam shows you what you all like.'**
  String get onboarding3Body;

  /// No description provided for @onboardingGuest.
  ///
  /// In en, this message translates to:
  /// **'Just look around as a guest'**
  String get onboardingGuest;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All · {count}'**
  String filterAll(int count);

  /// No description provided for @profileStats.
  ///
  /// In en, this message translates to:
  /// **'{favorites, plural, =1{1 favorite} other{{favorites} favorites}} · {groups, plural, =1{1 group} other{{groups} groups}}'**
  String profileStats(int favorites, int groups);

  /// No description provided for @guestName.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestName;

  /// No description provided for @guestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get guestSubtitle;

  /// No description provided for @loginHeadline.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginHeadline;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to sync your favorites and groups.'**
  String get loginSubtitle;

  /// No description provided for @registerHeadline.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerHeadline;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your favorites and plan trips with friends.'**
  String get registerSubtitle;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get licenses;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get locationTitle;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @currentLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Places around you'**
  String get currentLocationSubtitle;

  /// No description provided for @searchCity.
  ///
  /// In en, this message translates to:
  /// **'Search city'**
  String get searchCity;

  /// No description provided for @popularDestinations.
  ///
  /// In en, this message translates to:
  /// **'Popular destinations'**
  String get popularDestinations;

  /// No description provided for @noCityFound.
  ///
  /// In en, this message translates to:
  /// **'No matching city'**
  String get noCityFound;

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTitle;

  /// No description provided for @interestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interestsTitle;

  /// No description provided for @interestsHint.
  ///
  /// In en, this message translates to:
  /// **'Shows places that match at least one.'**
  String get interestsHint;

  /// No description provided for @radiusTitle.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get radiusTitle;

  /// No description provided for @radiusKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String radiusKm(int km);

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Show places'**
  String get applyFilters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetFilters;

  /// No description provided for @interestCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture & museums'**
  String get interestCulture;

  /// No description provided for @interestNature.
  ///
  /// In en, this message translates to:
  /// **'Nature & parks'**
  String get interestNature;

  /// No description provided for @interestHistory.
  ///
  /// In en, this message translates to:
  /// **'Sights & history'**
  String get interestHistory;

  /// No description provided for @interestBeach.
  ///
  /// In en, this message translates to:
  /// **'Beaches'**
  String get interestBeach;

  /// No description provided for @interestViews.
  ///
  /// In en, this message translates to:
  /// **'Viewpoints'**
  String get interestViews;

  /// No description provided for @interestFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get interestFamily;

  /// No description provided for @interestNightlife.
  ///
  /// In en, this message translates to:
  /// **'Nightlife'**
  String get interestNightlife;

  /// No description provided for @interestShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get interestShopping;

  /// No description provided for @emptyNoPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'No places here yet'**
  String get emptyNoPlacesTitle;

  /// No description provided for @emptyNoPlacesBody.
  ///
  /// In en, this message translates to:
  /// **'We don\'t have places for {place} yet. Try another destination.'**
  String emptyNoPlacesBody(String place);

  /// No description provided for @emptyFilteredTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your filters'**
  String get emptyFilteredTitle;

  /// No description provided for @emptyFilteredBody.
  ///
  /// In en, this message translates to:
  /// **'Try other interests or a larger distance.'**
  String get emptyFilteredBody;

  /// No description provided for @changePlace.
  ///
  /// In en, this message translates to:
  /// **'Change place'**
  String get changePlace;

  /// No description provided for @inviteCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeTitle;

  /// No description provided for @promptBestTime.
  ///
  /// In en, this message translates to:
  /// **'Best time'**
  String get promptBestTime;

  /// No description provided for @promptInsiderTip.
  ///
  /// In en, this message translates to:
  /// **'Insider tip'**
  String get promptInsiderTip;

  /// No description provided for @promptDontMiss.
  ///
  /// In en, this message translates to:
  /// **'Don\'t miss'**
  String get promptDontMiss;

  /// No description provided for @promptGoodFor.
  ///
  /// In en, this message translates to:
  /// **'Perfect for'**
  String get promptGoodFor;

  /// No description provided for @promptFunFact.
  ///
  /// In en, this message translates to:
  /// **'Did you know?'**
  String get promptFunFact;

  /// No description provided for @photoCreditShort.
  ///
  /// In en, this message translates to:
  /// **'Photo: {author}'**
  String photoCreditShort(String author);

  /// No description provided for @photoCreditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo credits'**
  String get photoCreditsTitle;

  /// No description provided for @photoCreditsHint.
  ///
  /// In en, this message translates to:
  /// **'Photos belong to their authors and are shown under the terms listed.'**
  String get photoCreditsHint;

  /// No description provided for @photoCreditUnknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get photoCreditUnknownAuthor;

  /// No description provided for @photoCreditGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get photoCreditGoogle;

  /// No description provided for @photoCreditWikimedia.
  ///
  /// In en, this message translates to:
  /// **'Wikimedia Commons'**
  String get photoCreditWikimedia;

  /// No description provided for @photoCreditNumber.
  ///
  /// In en, this message translates to:
  /// **'Photo {number}'**
  String photoCreditNumber(int number);

  /// No description provided for @errorOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get errorOpenLink;

  /// No description provided for @mapsChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Get directions with'**
  String get mapsChooseTitle;

  /// No description provided for @appleMaps.
  ///
  /// In en, this message translates to:
  /// **'Apple Maps'**
  String get appleMaps;

  /// No description provided for @googleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get googleMaps;

  /// No description provided for @fromCalendar.
  ///
  /// In en, this message translates to:
  /// **'From calendar'**
  String get fromCalendar;

  /// No description provided for @calendarPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a trip from your calendar'**
  String get calendarPickTitle;

  /// No description provided for @calendarPickHint.
  ///
  /// In en, this message translates to:
  /// **'We use the event\'s title, place and dates for the group. Nothing else leaves your phone.'**
  String get calendarPickHint;

  /// No description provided for @calendarPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'TripFam has no access to your calendar. You can allow it in the iPhone or Android settings.'**
  String get calendarPermissionDenied;

  /// No description provided for @errorLoadCalendar.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your calendar.'**
  String get errorLoadCalendar;

  /// No description provided for @calendarNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events in your calendar.'**
  String get calendarNoEvents;

  /// No description provided for @calendarCityNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t recognise the city. Please pick it.'**
  String get calendarCityNotFound;

  /// No description provided for @tripDatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Travel dates (optional)'**
  String get tripDatesLabel;

  /// No description provided for @clearTripDates.
  ///
  /// In en, this message translates to:
  /// **'Remove dates'**
  String get clearTripDates;

  /// No description provided for @textSourceWikipedia.
  ///
  /// In en, this message translates to:
  /// **'Text: Wikipedia, CC BY-SA'**
  String get textSourceWikipedia;

  /// No description provided for @openingHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHoursLabel;

  /// No description provided for @websiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get websiteLabel;

  /// No description provided for @osmAttribution.
  ///
  /// In en, this message translates to:
  /// **'Map data: © OpenStreetMap contributors'**
  String get osmAttribution;

  /// No description provided for @openingHoursWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Mon,Tue,Wed,Thu,Fri,Sat,Sun'**
  String get openingHoursWeekdays;

  /// No description provided for @openingHoursMonths.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get openingHoursMonths;

  /// No description provided for @openingHoursDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get openingHoursDaily;

  /// No description provided for @openingHoursAlwaysOpen.
  ///
  /// In en, this message translates to:
  /// **'Open 24 hours'**
  String get openingHoursAlwaysOpen;

  /// No description provided for @openingHoursClosed.
  ///
  /// In en, this message translates to:
  /// **'closed'**
  String get openingHoursClosed;

  /// No description provided for @openingHoursPublicHolidays.
  ///
  /// In en, this message translates to:
  /// **'public holidays'**
  String get openingHoursPublicHolidays;

  /// No description provided for @openingHoursSchoolHolidays.
  ///
  /// In en, this message translates to:
  /// **'school holidays'**
  String get openingHoursSchoolHolidays;

  /// No description provided for @openingHoursSunrise.
  ///
  /// In en, this message translates to:
  /// **'sunrise'**
  String get openingHoursSunrise;

  /// No description provided for @openingHoursSunset.
  ///
  /// In en, this message translates to:
  /// **'sunset'**
  String get openingHoursSunset;

  /// No description provided for @openingHoursEaster.
  ///
  /// In en, this message translates to:
  /// **'Easter'**
  String get openingHoursEaster;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsTitle;

  /// No description provided for @reviewsNone.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get reviewsNone;

  /// No description provided for @reviewsFew.
  ///
  /// In en, this message translates to:
  /// **'Only a few reviews so far. The average appears from 3 reviews.'**
  String get reviewsFew;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @reviewWrite.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get reviewWrite;

  /// No description provided for @reviewEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit your review'**
  String get reviewEdit;

  /// No description provided for @reviewSignInToWrite.
  ///
  /// In en, this message translates to:
  /// **'Sign in to write a review'**
  String get reviewSignInToWrite;

  /// No description provided for @reviewSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your review'**
  String get reviewSheetTitle;

  /// No description provided for @reviewTextHint.
  ///
  /// In en, this message translates to:
  /// **'What did you like? (optional)'**
  String get reviewTextHint;

  /// No description provided for @reviewRatingRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose 1 to 5 stars.'**
  String get reviewRatingRequired;

  /// No description provided for @reviewSaved.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review!'**
  String get reviewSaved;

  /// No description provided for @reviewDeleted.
  ///
  /// In en, this message translates to:
  /// **'Review deleted.'**
  String get reviewDeleted;

  /// No description provided for @reviewDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete review'**
  String get reviewDeleteButton;

  /// No description provided for @reviewReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reviewReport;

  /// No description provided for @reviewReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this review?'**
  String get reviewReportTitle;

  /// No description provided for @reviewReportBody.
  ///
  /// In en, this message translates to:
  /// **'The text will be hidden until we have checked it.'**
  String get reviewReportBody;

  /// No description provided for @reviewReported.
  ///
  /// In en, this message translates to:
  /// **'Thanks. The review is hidden for now.'**
  String get reviewReported;

  /// No description provided for @reviewAnonymousAuthor.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get reviewAnonymousAuthor;

  /// No description provided for @reviewYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get reviewYou;

  /// No description provided for @reviewStarsLabel.
  ///
  /// In en, this message translates to:
  /// **'{stars} of 5 stars'**
  String reviewStarsLabel(int stars);

  /// No description provided for @errorSaveReview.
  ///
  /// In en, this message translates to:
  /// **'Your review could not be saved.'**
  String get errorSaveReview;

  /// No description provided for @errorLoadReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews could not be loaded.'**
  String get errorLoadReviews;

  /// No description provided for @favoritesMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get favoritesMapTitle;

  /// No description provided for @favoritesShowMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get favoritesShowMap;

  /// No description provided for @favoritesMapEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your favorites will appear here as pins.'**
  String get favoritesMapEmpty;

  /// No description provided for @mapsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The map is not set up in this build yet (Mapbox token missing).'**
  String get mapsNotConfigured;

  /// No description provided for @dayPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Day plan'**
  String get dayPlanTitle;

  /// No description provided for @dayPlanSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Tick the places for your day plan.'**
  String get dayPlanSelectHint;

  /// No description provided for @dayPlanSelectPlace.
  ///
  /// In en, this message translates to:
  /// **'Select for the day plan'**
  String get dayPlanSelectPlace;

  /// No description provided for @dayPlanCreate.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Create day plan (1 place)} other{Create day plan ({count} places)}}'**
  String dayPlanCreate(int count);

  /// No description provided for @dayPlanView.
  ///
  /// In en, this message translates to:
  /// **'View day plan'**
  String get dayPlanView;

  /// No description provided for @dayPlanEndNearMe.
  ///
  /// In en, this message translates to:
  /// **'End near me'**
  String get dayPlanEndNearMe;

  /// No description provided for @dayPlanStartNearMe.
  ///
  /// In en, this message translates to:
  /// **'Start near me'**
  String get dayPlanStartNearMe;

  /// No description provided for @dayPlanEndNearMeHint.
  ///
  /// In en, this message translates to:
  /// **'Starts at the farthest place, so you finish near where you\'re staying.'**
  String get dayPlanEndNearMeHint;

  /// No description provided for @dayPlanStartNearMeHint.
  ///
  /// In en, this message translates to:
  /// **'Starts at the closest place and works outwards.'**
  String get dayPlanStartNearMeHint;

  /// No description provided for @dayPlanNoLocation.
  ///
  /// In en, this message translates to:
  /// **'You\'re not near these places, so the route starts at the first stop. Drag to change it.'**
  String get dayPlanNoLocation;

  /// No description provided for @dayPlanLeg.
  ///
  /// In en, this message translates to:
  /// **'{distance} as the crow flies'**
  String dayPlanLeg(String distance);

  /// No description provided for @dayPlanTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {distance} as the crow flies'**
  String dayPlanTotal(String distance);

  /// No description provided for @dayPlanOpenRoute.
  ///
  /// In en, this message translates to:
  /// **'Open route in Google Maps'**
  String get dayPlanOpenRoute;

  /// No description provided for @dayPlanRouteCapped.
  ///
  /// In en, this message translates to:
  /// **'Google Maps shows up to 10 stops; the first 10 are opened.'**
  String get dayPlanRouteCapped;

  /// No description provided for @dayPlanAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the group creator can change the day plan.'**
  String get dayPlanAdminOnly;

  /// No description provided for @dayPlanNone.
  ///
  /// In en, this message translates to:
  /// **'No day plan yet.'**
  String get dayPlanNone;

  /// No description provided for @errorSaveDayPlan.
  ///
  /// In en, this message translates to:
  /// **'The day plan could not be saved.'**
  String get errorSaveDayPlan;

  /// No description provided for @distanceKmValue.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKmValue(String km);

  /// No description provided for @distanceMetersValue.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String distanceMetersValue(int meters);

  /// No description provided for @matchStamp.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get matchStamp;

  /// No description provided for @limitTimeShort.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get limitTimeShort;

  /// No description provided for @sessionSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get sessionSetupTitle;

  /// No description provided for @sessionSwipesValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 swipe} other{{count} swipes}}'**
  String sessionSwipesValue(int count);

  /// No description provided for @sessionMinutesValue.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String sessionMinutesValue(int count);

  /// No description provided for @sessionLimitLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get sessionLimitLess;

  /// No description provided for @sessionLimitMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get sessionLimitMore;

  /// No description provided for @dayPlanEndShort.
  ///
  /// In en, this message translates to:
  /// **'End near me'**
  String get dayPlanEndShort;

  /// No description provided for @dayPlanStartShort.
  ///
  /// In en, this message translates to:
  /// **'Start near me'**
  String get dayPlanStartShort;

  /// No description provided for @placeSectionInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get placeSectionInfo;

  /// No description provided for @placeSectionSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get placeSectionSources;

  /// No description provided for @tagRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get tagRestaurant;

  /// No description provided for @tagCafe.
  ///
  /// In en, this message translates to:
  /// **'Café'**
  String get tagCafe;

  /// No description provided for @tagBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get tagBar;

  /// No description provided for @tagPub.
  ///
  /// In en, this message translates to:
  /// **'Pub'**
  String get tagPub;

  /// No description provided for @tagBiergarten.
  ///
  /// In en, this message translates to:
  /// **'Beer garden'**
  String get tagBiergarten;

  /// No description provided for @tagNightClub.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get tagNightClub;

  /// No description provided for @interestFood.
  ///
  /// In en, this message translates to:
  /// **'Food & drink'**
  String get interestFood;

  /// No description provided for @homeHeadlineCity.
  ///
  /// In en, this message translates to:
  /// **'What are we doing in {city} today?'**
  String homeHeadlineCity(String city);

  /// No description provided for @homeHeadlineNearby.
  ///
  /// In en, this message translates to:
  /// **'What are we doing today?'**
  String get homeHeadlineNearby;

  /// No description provided for @homeStartSwiping.
  ///
  /// In en, this message translates to:
  /// **'Start swiping'**
  String get homeStartSwiping;

  /// No description provided for @homeStartSwipingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No places yet} =1{1 place waiting for you} other{{count} places waiting for you}}'**
  String homeStartSwipingCount(int count);

  /// No description provided for @homeSectionMustSees.
  ///
  /// In en, this message translates to:
  /// **'Must-sees'**
  String get homeSectionMustSees;

  /// No description provided for @homeSectionTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get homeSectionTonight;

  /// No description provided for @homeSectionHiddenGems.
  ///
  /// In en, this message translates to:
  /// **'Hidden gems'**
  String get homeSectionHiddenGems;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeSeeAll;

  /// No description provided for @homeVenuesComingTitle.
  ///
  /// In en, this message translates to:
  /// **'Bars & restaurants coming soon'**
  String get homeVenuesComingTitle;

  /// No description provided for @homeVenuesComingBody.
  ///
  /// In en, this message translates to:
  /// **'We\'re collecting the best spots for your evening.'**
  String get homeVenuesComingBody;

  /// No description provided for @collectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Try another city.'**
  String get collectionEmpty;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @profileFavoritesMap.
  ///
  /// In en, this message translates to:
  /// **'Favorites on the map'**
  String get profileFavoritesMap;

  /// No description provided for @inviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'ABC123'**
  String get inviteCodeHint;

  /// No description provided for @paypalHandleTitle.
  ///
  /// In en, this message translates to:
  /// **'PayPal.me name'**
  String get paypalHandleTitle;

  /// No description provided for @paypalHandleNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get paypalHandleNone;

  /// No description provided for @paypalHandleBody.
  ///
  /// In en, this message translates to:
  /// **'Trip members can pay you back through your paypal.me link. Optional.'**
  String get paypalHandleBody;

  /// No description provided for @paypalHandlePrefix.
  ///
  /// In en, this message translates to:
  /// **'paypal.me/'**
  String get paypalHandlePrefix;

  /// No description provided for @paypalHandleHint.
  ///
  /// In en, this message translates to:
  /// **'yourname'**
  String get paypalHandleHint;

  /// No description provided for @tripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripsTitle;

  /// No description provided for @tripsPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned trips'**
  String get tripsPlanned;

  /// No description provided for @tripsPast.
  ///
  /// In en, this message translates to:
  /// **'Past trips'**
  String get tripsPast;

  /// No description provided for @tripsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get tripsEmptyTitle;

  /// No description provided for @tripsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Plan a trip with friends: collect ideas, vote, plan the days and split the costs.'**
  String get tripsEmptyBody;

  /// No description provided for @tripNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan a new trip'**
  String get tripNewTitle;

  /// No description provided for @tripJoinByCode.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get tripJoinByCode;

  /// No description provided for @tripCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create trip'**
  String get tripCreateButton;

  /// No description provided for @tripCountdown.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{today} =1{tomorrow} other{in {days} days}}'**
  String tripCountdown(int days);

  /// No description provided for @tripOngoing.
  ///
  /// In en, this message translates to:
  /// **'On the road'**
  String get tripOngoing;

  /// No description provided for @tripPeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String tripPeopleCount(int count);

  /// No description provided for @tripOpenPolls.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 open poll} other{{count} open polls}}'**
  String tripOpenPolls(int count);

  /// No description provided for @tripTabPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tripTabPlan;

  /// No description provided for @tripTabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tripTabMap;

  /// No description provided for @tripTabJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get tripTabJournal;

  /// No description provided for @tripTabCosts.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get tripTabCosts;

  /// No description provided for @tripSoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get tripSoon;

  /// No description provided for @tripJournalSoon.
  ///
  /// In en, this message translates to:
  /// **'The travel journal is coming soon.'**
  String get tripJournalSoon;

  /// No description provided for @tripInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get tripInvite;

  /// No description provided for @tripInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get tripInviteFriends;

  /// No description provided for @tripInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Join our trip \"{trip}\" on TripFam! Open Trips, tap + and join with the code {code}.'**
  String tripInviteMessage(String trip, String code);

  /// No description provided for @tripInviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invitation copied. Paste it into a chat.'**
  String get tripInviteCopied;

  /// No description provided for @tripLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave trip'**
  String get tripLeave;

  /// No description provided for @tripDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete trip'**
  String get tripDelete;

  /// No description provided for @tripNewPoll.
  ///
  /// In en, this message translates to:
  /// **'New poll'**
  String get tripNewPoll;

  /// No description provided for @tripPollQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Question, e.g. Where do we stay?'**
  String get tripPollQuestionHint;

  /// No description provided for @tripPollOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String tripPollOptionHint(int number);

  /// No description provided for @tripPollAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get tripPollAddOption;

  /// No description provided for @tripPollCreate.
  ///
  /// In en, this message translates to:
  /// **'Start poll'**
  String get tripPollCreate;

  /// No description provided for @tripPollVoted.
  ///
  /// In en, this message translates to:
  /// **'{voters} of {members} voted'**
  String tripPollVoted(int voters, int members);

  /// No description provided for @tripPollClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get tripPollClosed;

  /// No description provided for @tripPollClose.
  ///
  /// In en, this message translates to:
  /// **'End poll'**
  String get tripPollClose;

  /// No description provided for @tripPollReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen poll'**
  String get tripPollReopen;

  /// No description provided for @tripWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get tripWishlist;

  /// No description provided for @tripAddIdea.
  ///
  /// In en, this message translates to:
  /// **'+ Idea'**
  String get tripAddIdea;

  /// No description provided for @tripWishlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Collect what you want to see and do. Ideas with a place go into the day plan.'**
  String get tripWishlistEmpty;

  /// No description provided for @tripAddIdeaTitle.
  ///
  /// In en, this message translates to:
  /// **'New idea'**
  String get tripAddIdeaTitle;

  /// No description provided for @tripIdeaHint.
  ///
  /// In en, this message translates to:
  /// **'Place, activity or link'**
  String get tripIdeaHint;

  /// No description provided for @tripAddIdeaButton.
  ///
  /// In en, this message translates to:
  /// **'Add idea'**
  String get tripAddIdeaButton;

  /// No description provided for @tripIdeaSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Places in {city}'**
  String tripIdeaSuggestions(String city);

  /// No description provided for @tripIdeaBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String tripIdeaBy(String name);

  /// No description provided for @tripIdeaByYou.
  ///
  /// In en, this message translates to:
  /// **'by you'**
  String get tripIdeaByYou;

  /// No description provided for @tripIdeaFromSwipe.
  ///
  /// In en, this message translates to:
  /// **'from swiping'**
  String get tripIdeaFromSwipe;

  /// No description provided for @tripIdeaFromLink.
  ///
  /// In en, this message translates to:
  /// **'link'**
  String get tripIdeaFromLink;

  /// No description provided for @tripIdeaDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete idea?'**
  String get tripIdeaDeleteTitle;

  /// No description provided for @tripLikeIdea.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get tripLikeIdea;

  /// No description provided for @tripBuildPlan.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Build day plan from 1 idea} other{Build day plan from {count} ideas}}'**
  String tripBuildPlan(int count);

  /// No description provided for @tripPlanNeedsIdeas.
  ///
  /// In en, this message translates to:
  /// **'Add ideas with a place first'**
  String get tripPlanNeedsIdeas;

  /// No description provided for @tripShowDayPlan.
  ///
  /// In en, this message translates to:
  /// **'Day plan'**
  String get tripShowDayPlan;

  /// No description provided for @tripPlanStops.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}}'**
  String tripPlanStops(int count);

  /// No description provided for @tripSwipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect ideas by swiping'**
  String get tripSwipeTitle;

  /// No description provided for @tripSwipeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everyone swipes through places in {city}'**
  String tripSwipeSubtitle(String city);

  /// No description provided for @tripSwipeSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone swipes through the same places. Afterwards you see what the group likes and can add it to the wishlist.'**
  String get tripSwipeSheetBody;

  /// No description provided for @tripSwipeLive.
  ///
  /// In en, this message translates to:
  /// **'Swipe round is running'**
  String get tripSwipeLive;

  /// No description provided for @tripImportMatches.
  ///
  /// In en, this message translates to:
  /// **'Add matches to the wishlist'**
  String get tripImportMatches;

  /// No description provided for @tripMatchesImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new matches to add} =1{1 idea added} other{{count} ideas added}}'**
  String tripMatchesImported(int count);

  /// No description provided for @tripNoPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'No day plan yet'**
  String get tripNoPlanTitle;

  /// No description provided for @tripNoPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Collect ideas with a place on the wishlist, then build the plan.'**
  String get tripNoPlanBody;

  /// No description provided for @tripDayN.
  ///
  /// In en, this message translates to:
  /// **'Day {number}'**
  String tripDayN(int number);

  /// No description provided for @tripDaySummary.
  ///
  /// In en, this message translates to:
  /// **'{stops, plural, =1{1 stop} other{{stops} stops}} · {distance} on foot · {minutes} min'**
  String tripDaySummary(int stops, String distance, int minutes);

  /// No description provided for @tripDayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned for this day.'**
  String get tripDayEmpty;

  /// No description provided for @tripWalkMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min walk'**
  String tripWalkMinutes(int minutes);

  /// No description provided for @tripYouGet.
  ///
  /// In en, this message translates to:
  /// **'You get'**
  String get tripYouGet;

  /// No description provided for @tripYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get tripYouOwe;

  /// No description provided for @tripAllSettled.
  ///
  /// In en, this message translates to:
  /// **'All settled'**
  String get tripAllSettled;

  /// No description provided for @tripOwesYou.
  ///
  /// In en, this message translates to:
  /// **'{name} owes you'**
  String tripOwesYou(String name);

  /// No description provided for @tripYouOweTo.
  ///
  /// In en, this message translates to:
  /// **'You owe {name}'**
  String tripYouOweTo(String name);

  /// No description provided for @tripOwes.
  ///
  /// In en, this message translates to:
  /// **'{from} owes {to}'**
  String tripOwes(String from, String to);

  /// No description provided for @tripRequestPaypal.
  ///
  /// In en, this message translates to:
  /// **'Request via PayPal link'**
  String get tripRequestPaypal;

  /// No description provided for @tripPayWithPaypal.
  ///
  /// In en, this message translates to:
  /// **'Pay {name} with PayPal'**
  String tripPayWithPaypal(String name);

  /// No description provided for @tripRequestIntro.
  ///
  /// In en, this message translates to:
  /// **'Costs for \"{trip}\":'**
  String tripRequestIntro(String trip);

  /// No description provided for @tripRequestLine.
  ///
  /// In en, this message translates to:
  /// **'{name}: {amount}'**
  String tripRequestLine(String name, String amount);

  /// No description provided for @tripPaypalRequestLine.
  ///
  /// In en, this message translates to:
  /// **'{name}: {amount}, {link}'**
  String tripPaypalRequestLine(String name, String amount, String link);

  /// No description provided for @tripRequestCopied.
  ///
  /// In en, this message translates to:
  /// **'Request copied. Paste it into your group chat.'**
  String get tripRequestCopied;

  /// No description provided for @tripRequestCopiedNoPaypal.
  ///
  /// In en, this message translates to:
  /// **'Request copied. Add your PayPal.me name in Settings to include a payment link.'**
  String get tripRequestCopiedNoPaypal;

  /// No description provided for @tripExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get tripExpenses;

  /// No description provided for @tripExpensesTotal.
  ///
  /// In en, this message translates to:
  /// **'total {amount}'**
  String tripExpensesTotal(String amount);

  /// No description provided for @tripExpensesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet. Add what someone paid for the group.'**
  String get tripExpensesEmpty;

  /// No description provided for @tripAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get tripAddExpense;

  /// No description provided for @tripExpenseTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What for? e.g. Dinner'**
  String get tripExpenseTitleHint;

  /// No description provided for @tripExpenseAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get tripExpenseAmountHint;

  /// No description provided for @tripExpensePaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get tripExpensePaidBy;

  /// No description provided for @tripExpenseSplitWith.
  ///
  /// In en, this message translates to:
  /// **'Split between'**
  String get tripExpenseSplitWith;

  /// No description provided for @tripExpenseSplitEqually.
  ///
  /// In en, this message translates to:
  /// **'Split equally'**
  String get tripExpenseSplitEqually;

  /// No description provided for @tripExpensePerPerson.
  ///
  /// In en, this message translates to:
  /// **'Split equally: {amount} per person'**
  String tripExpensePerPerson(String amount);

  /// No description provided for @tripExpenseTitleMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter what the expense was for.'**
  String get tripExpenseTitleMissing;

  /// No description provided for @tripExpenseAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero, e.g. 12,50.'**
  String get tripExpenseAmountInvalid;

  /// No description provided for @tripExpenseNoParticipants.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one person.'**
  String get tripExpenseNoParticipants;

  /// No description provided for @tripExpenseDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete expense?'**
  String get tripExpenseDeleteTitle;

  /// No description provided for @tripYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get tripYou;

  /// No description provided for @tripYouPaid.
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get tripYouPaid;

  /// No description provided for @tripSplitEqually.
  ///
  /// In en, this message translates to:
  /// **'split equally'**
  String get tripSplitEqually;

  /// No description provided for @tripSplitPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{only 1 person} other{only {count} people}}'**
  String tripSplitPeople(int count);

  /// No description provided for @tripSplitOnlyFor.
  ///
  /// In en, this message translates to:
  /// **'only for {name}'**
  String tripSplitOnlyFor(String name);

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to set a new password.'**
  String get forgotPasswordBody;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @resetLinkSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get resetLinkSentTitle;

  /// No description provided for @resetLinkSentBody.
  ///
  /// In en, this message translates to:
  /// **'If there is an account for {email}, a link to reset your password is on its way. It is valid for one hour. Also check your spam folder.'**
  String resetLinkSentBody(String email);

  /// No description provided for @resendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get resendResetLink;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Send again in {seconds} s'**
  String resendIn(int seconds);

  /// No description provided for @useOtherEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useOtherEmail;

  /// No description provided for @resetLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'The link could not be sent. Please try again.'**
  String get resetLinkFailed;

  /// No description provided for @resetPasswordSetting.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordSetting;

  /// No description provided for @resetPasswordSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a link to set a new password'**
  String get resetPasswordSettingSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
