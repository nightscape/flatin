Feature: Word Classification
  As a user
  I want to classify Latin words
  So that I can practice identifying word forms

  Scenario: User opens word classification screen
    Given the app is running
    When I am on the "home" screen
    And I tap on "home.wordClassification.button"
    Then I should see "wordClassification.declension" or "wordClassification.conjugation" in the title
    And I should see a word displayed
    And I should see classification dropdowns
    And I take a screenshot named "word_classification_initial"

  Scenario: User classifies a word correctly
    Given the app is running
    When I am on the "home" screen
    And I tap on "home.wordClassification.button"
    And I wait for "the word" to load
    And I select classification options
    And I tap on "wordClassification.check.button"
    Then I should see validation feedback
    And I take a screenshot named "word_classification_checked"
