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

# Package Installer Goals:
* Put jenkins.war somewhere else so casual users are not exposed to it
    * `/Library/Application Support/Jenkins/jenkins.war`?
* Use the documented `pkgbuild` commnd in OS X
    * Stable, documented format that is easier to manipulate than `.pbdoc` files (XML property lists)
    * No more poking into PackageMaker.app
