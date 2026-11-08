cmake_minimum_required(VERSION 3.22)
project(omni-shell-prototipo LANGUAGES CXX)
# OMNI Shell — prototipo anticipato dell'interfaccia (non M4). Qt 6 / QML.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick Test)

add_library(omni_desktopentries STATIC src/desktopentries.cpp src/desktopentries.h)
target_link_libraries(omni_desktopentries PUBLIC Qt6::Core)
target_include_directories(omni_desktopentries PUBLIC src)

add_executable(omni-shell-prototipo src/main.cpp src/recorder.cpp src/recorder.h)
target_link_libraries(omni-shell-prototipo PRIVATE omni_desktopentries Qt6::Gui Qt6::Quick)
target_compile_definitions(omni-shell-prototipo PRIVATE OMNI_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
target_compile_options(omni-shell-prototipo PRIVATE -Wall -Wextra)

enable_testing()
add_executable(tst_desktopentries tests/tst_desktopentries.cpp)
target_link_libraries(tst_desktopentries PRIVATE omni_desktopentries Qt6::Test)
add_test(NAME desktopentries COMMAND tst_desktopentries)

find_program(QMLTESTRUNNER qmltestrunner HINTS /usr/lib/qt6/bin /usr/lib64/qt6/bin /usr/lib/x86_64-linux-gnu/qt6/bin)
add_test(NAME qml COMMAND ${QMLTESTRUNNER} -import ${CMAKE_CURRENT_SOURCE_DIR}/qml -input ${CMAKE_CURRENT_SOURCE_DIR}/tests)
set_tests_properties(qml desktopentries PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
