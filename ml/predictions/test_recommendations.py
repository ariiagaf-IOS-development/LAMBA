import unittest

from predictions.explanations import PART_RECOMMENDATIONS, recommendation_for


class RecommendationTest(unittest.TestCase):
    def test_all_mvp_parts_have_recommendations_for_every_risk_level(self):
        expected_parts = {
            "engine_oil",
            "brake_pads",
            "battery",
            "tires",
            "air_filter",
            "timing_belt",
        }

        self.assertEqual(set(PART_RECOMMENDATIONS), expected_parts)
        for part_category in expected_parts:
            self.assertEqual(
                set(PART_RECOMMENDATIONS[part_category]),
                {"low", "medium", "high"},
            )

    def test_part_aliases_use_part_specific_recommendations(self):
        self.assertIn("oil filter change", recommendation_for("medium", "Oil"))
        self.assertIn("brake inspection", recommendation_for("high", "Brakes"))
        self.assertIn("timing belt", recommendation_for("high", "Timing Belt"))

    def test_unknown_part_uses_risk_specific_default(self):
        action = recommendation_for("medium", "Fuel pump", "fuel_pump")

        self.assertEqual(action, "Schedule inspection for Fuel pump soon.")


if __name__ == "__main__":
    unittest.main()
