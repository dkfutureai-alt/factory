# Mobile Inventory / cylinder scan workspace integrity

The scanner always receives the workspace organization ID from the actual MobileData
workspace, including its notification deep-link, Scan tab and Inventory module entry
points. It never queries for the user's first organization membership; a multi-tenant
user must not silently scan a different organization's inventory or gas assets.

Starting a new lookup immediately clears the prior asset and inventory matches.
Any exception also leaves the previous results cleared. The app does not present
an earlier cylinder as the match for a newly scanned serial or QR.
All queries still use the existing tenant and factory RLS policies. A scan does
not release a cylinder, change stock or authorize customer custody.

Real camera verification on physical phones, deliberate multi-organization
pilot accounts, offline behavior and asset custody accounting remain separate
release gates. This change is safe source-only work and does not deploy data.
