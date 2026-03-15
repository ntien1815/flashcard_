allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
  
    val flutterProjectRoot = rootProject.projectDir.parentFile
    layout.buildDirectory.set(
        file("${flutterProjectRoot}/build/${project.name}")
    )
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}