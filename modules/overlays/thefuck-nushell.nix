final: prev: {
  thefuck = prev.thefuck.overrideAttrs (old:
    {
      src = prev.fetchFromGitHub {
        owner = "afresquet";
        repo = "thefuck";
        rev = "66641acbcce2247426a90d310364596a8b455cec";
        hash = "sha256-dD7SOrjnlMcOgsnKXe1VeZJift0w9T0tujcXdInKANk=";
      };
    }
  );
}
  
