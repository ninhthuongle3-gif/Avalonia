# Operator cutout art

`source/operator_parts_sheet.png` was generated with the OpenAI image generation tool for this project from the user's character direction. It has a transparent background and contains a side-view tactical operator, shield, rifle, and pistol.

The PNG files in `parts/` are crops from that sheet. Small disconnected generation artifacts were removed by alpha-component cleanup. `scripts/cutout_rig.gd` loads these parts and parents them to a runtime `Skeleton2D/Bone2D` hierarchy. The source sheet is intentionally retained so the crops, joint pivots, and proportions can be revised without regenerating the concept.

The original user reference image is not included in the repository. Review the final character design and relevant platform policy before commercial release.
