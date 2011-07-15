# Pref Pane Goals
* Simple interface for common configuration
    * HTTP Port
    * AJP Port
    * jenkins.war Location
    * Prefix (?)
    * Heap Size
    * Jenkins Home
    * Extra flags (text box)
* Simple start/stop
* Simple update
* Full Help system
    * Make it easier for new users to customize Jenkins for their installation
* Easily Localizeable
    * A native speaker should be able to edit a text file and add a new definition
    * Must not require a Mac to localize

# Package Installer Goals:
* Put jenkins.war somewhere else so casual users are not exposed to it
    * `/Library/Application Support/Jenkins/jenkins.war`?
* Use the documented `pkgbuild` command in OS X
    * Stable, documented format that is easier to manipulate than `.pbdoc` files (XML property lists)
    * No more poking into PackageMaker.app
