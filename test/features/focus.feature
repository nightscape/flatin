Feature: Focus on a word group
  As a learner
  I want to narrow one round to a group of words
  So that I can practise the words I find hard

  Scenario: A round with the focus "Unregelmäßige Verben" asks only irregular verbs
    Given the device language is German
    And the app is running
    When I start a round with the focus "Unregelmäßige Verben"
    Then every task of the round asks an irregular verb
