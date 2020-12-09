#!/bin/bash

SRC="src/main"

mkdir -p .results
curl -o ".results/compile.svg" "https://img.shields.io/badge/Compile-failed-critical"
curl -o ".results/checkstyle.svg" "https://img.shields.io/badge/Code%20Style-n/a-gray"
curl -o ".results/test.svg" "https://img.shields.io/badge/Tests%20Passed-0/0-gray"

mvn compile > .results/compile.log 2>&1 || exit 0
curl -o ".results/compile.svg" "https://img.shields.io/badge/Compile-passed-success"

tmppom="$(mktemp -d)/checkstyle-pom.xml"

cat << EOD > "$tmppom"
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>InternetGuru</groupId>
  <artifactId>java-checkstyle</artifactId>
  <version>1</version>
  <properties>
    <maven.compiler.source>1.8</maven.compiler.source>
    <maven.compiler.target>1.8</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
  <build>
    <sourceDirectory>$(pwd)/$SRC</sourceDirectory>
    <testSourceDirectory>$(pwd)/src/test</testSourceDirectory>
    <pluginManagement>
      <plugins>
         <plugin>
           <groupId>org.apache.maven.plugins</groupId>
           <artifactId>maven-checkstyle-plugin</artifactId>
           <version>3.1.1</version>
           <configuration>
             <configLocation>google_checks.xml</configLocation>
             <encoding>UTF-8</encoding>
             <consoleOutput>true</consoleOutput>
             <failsOnError>true</failsOnError>
             <linkXRef>false</linkXRef>
           </configuration>
           <executions>
             <execution>
               <id>validate</id>
               <phase>validate</phase>
               <goals>
                 <goal>check</goal>
               </goals>
             </execution>
           </executions>
         </plugin>
      </plugins>
    </pluginManagement>
  </build>
</project>
EOD

# run checkstyle and save warnings and errors into log
errs=$(mvn -f "$tmppom" checkstyle:check | grep '^\[\(WARN\|ERROR\)' | tee .results/checkstyle.log | wc -l) \
  || exit 1
lines=$(find $SRC -name "*.java" -exec cat {} + | wc -l)
perc=100
[[ $errs -gt 0 ]] \
  && perc=$(( 99 - errs * 100 / lines ))

echo "[$perc]"

# output results to .results/checkstyle.json
color="brightgreen"
[[ $perc -lt 85 ]] \
  && color="green"
[[ $perc -lt 70 ]] \
  && color="yellow"
[[ $perc -lt 55 ]] \
  && color="orange"
[[ $perc -lt 45 ]] \
  && color="red"

curl -o ".results/checkstyle.svg" "https://img.shields.io/badge/Code%20Style-$perc%20%25-$color"

test_color=success
mvn test > .results/test.log 2>&1 || test_color=critical
summary="$(grep 'Tests run:' .results/test.log | head -n1)"
runs="$(tr -d "," <<< "$summary" | cut -d" " -f4)"
failures="$(tr -d "," <<< "$summary" | cut -d" " -f6)"
passed="$((runs - failures))"
curl -o ".results/test.svg" "https://img.shields.io/badge/Tests%20Passed-$passed/$runs-$test_color"
