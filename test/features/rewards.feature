Feature: Rewards
  As a learner
  I want my answers to earn coins and my finished rounds to build a town
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

  Scenario: Finishing a round adds a building and names the next one
    Given I have built 2 buildings
    And the app is running
    When I start a round
    And I finish the round
    And I leave the round
    Then my town should have 3 buildings
    And the next building should be "taberna"

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
