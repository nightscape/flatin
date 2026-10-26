Feature: Store pictures
  As the publisher
  I want phone pictures of the app in a fixed demo state
  So that the store listing shows what the app does today

  Background:
    Given the device language is the store locale
    And I have 1250 coins
    And I have built 5 buildings
    And the app is running

  Scenario: Home screen with town and coins
    Then the screen looks like "store-1100-startseite.png"

  Scenario: A practice task
    When I start a round
    Then the screen looks like "store-1200-aufgabe.png"

  Scenario: The course position settings
    When I open the drawer
    And I tap on "drawer.settings"
    Then the screen looks like "store-1300-kursstand.png"

  Scenario: The town shop
    When I tap on "home.town"
    And I tap on "town.build"
    Then the screen looks like "store-1400-laden.png"
