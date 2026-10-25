Feature: Rewards
  As a learner
  I want my answers to earn coins and my coins to buy a town
  So that practising feels rewarding

  Scenario: A right answer earns 10 coins
    Given I have 20 coins
    And the app is running
    When I start a round
    And I answer the task correctly
    And I leave the round
    Then I should have 30 coins

  Scenario: A task answered right on the second try earns 5 coins
    Given I have 0 coins
    And the app is running
    When I start a round
    And I answer the task wrongly
    And I finish the round
    And I leave the round
    Then I should have 95 coins

  Scenario: Finishing a round adds no building
    Given I have built 2 buildings
    And the app is running
    When I start a round
    And I finish the round
    And I leave the round
    Then my town should have 2 buildings

  Scenario: A building bought with enough coins appears in the town
    Given I have 900 coins
    And the app is running
    When I buy "templum"
    Then I should have 300 coins
    And the town shows "templum"

  Scenario: A building that costs more than my coins cannot be bought
    Given I have 500 coins
    And the app is running
    Then I cannot buy "templum"

  Scenario: A reward I switched off is not shown
    Given I switched the "points" reward off
    And I have 20 coins
    And the app is running
    Then I should see no coins

  Scenario: A town I switched off is not shown
    Given I switched the "town" reward off
    And I have built 2 buildings
    And the app is running
    Then I should see no town
