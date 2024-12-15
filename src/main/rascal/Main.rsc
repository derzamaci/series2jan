module Main

import IO;
import lang::java::m3::Core;
import lang::java::m3::AST;
import List;
import Set;
import String;
import Node;
import Map;
import Location;
import lang::json::IO;
import Type;



// TODO
// implement mass instead of arity
// see how to make json clean for export


int main(int testArgument=0) {
    println("argument: <testArgument>");


    loc testJavaProject = |file://C:/Users/james/OneDrive/Desktop/SEseries/series2Rascal/series2jan/rascalTestJava|; // |cwd://smallsql|;
    loc smallSQL = |file:///home/jan/Nextcloud/uni/SEvolution/series2-Jan/smallsql/smallsql0.21_src|;
    loc bigSQL = |file://C:/Users/james/OneDrive/Desktop/SEseries/series2Rascal/series2jan/SQLbigProject/hsqldb-2.3.1|;
    list[Declaration]  asts = getASTs(smallSQL);

    list[list[node]] cloneClasses = findClones(asts);

    loc cloneClassJson = |file:///home/jan/Nextcloud/uni/SEvolution/series2_james/clone-visuals/src/outputFromRascal/cloneClassTest.json|;
    loc locPerFileJson = |file:///home/jan/Nextcloud/uni/SEvolution/series2_james/clone-visuals/src/outputFromRascal/locPerFileTest.json|;
   
    exportToJson(cloneClasses, cloneClassJson);
    exportLocPerFile(asts, locPerFileJson);
    
    return testArgument;
}


list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}

// returns locations, lines of the file - this helps to get the actual lines of code of the clone
map[loc, list[str]] getRawLinesFromAST(list[Declaration] asts) {
    // Step 1: Extract useful lines per file from the AST
    map[loc, set[int]] lines_map = ();
    list[loc] locs = [];

    visit (asts) {
        case node n: 
            if (n.src ?) {
                locs += n.src;
            }
    }

    for (myloc <- locs) {
        int begin_line = myloc.begin.line;
        int end_line = myloc.end.line;
        loc key = myloc.top;
        if (key notin lines_map) {
            lines_map[key] = {begin_line, end_line};
        } else {
            lines_map[key] += {begin_line, end_line};
        }
    }

    // Step 2: Read the content of each file and split it into lines
    map[loc, list[str]] fileLinesMap = ();
    set[loc] files = { k | k <- lines_map };
    for (file <- files) {
        list[str] codeLines = split("\n", readFile(file));
        list[str] newCodeLines = [];
        for (line <- codeLines) {
            line += "\n";
            newCodeLines += line;
        }
        fileLinesMap[file] = newCodeLines;
    }

    return fileLinesMap;
}

// helper function for creating json
map[loc, tuple[int, list[str]]] getCloneClassInfo(list[Declaration] asts) {
    map[loc, list[str]] allLines = getRawLinesFromAST(asts);

    map[loc, tuple[int, list[str]]] codeClassInfo = ();

    for (loc key <- allLines) {
        codeClassInfo[key] = <size(allLines[key]), allLines[key]>;
    }

    return codeClassInfo;
}

// Gets the amount of lines of code each file has and returens map with [locaition of file, number of lines]
map[loc, int] getLinesPerFile(list[Declaration] asts) {
    list[loc] locs = [];

    visit (asts) {
            case node n: if (n.src ?) locs += n.src;
    }
    // this creates a map of files, with for every file the lines which actually have code
    map[loc, int] linesPerFile = ();
    for (myloc <- locs) {
        int endLine = myloc.end.line;
        loc key = myloc.top;
        linesPerFile[key] = endLine;
    }

    return linesPerFile;
}

// Writes LOC per file to json 
void exportLocPerFile(list[Declaration] asts, loc path) {

    // writeJSON(path, getLinesPerFile(asts), unpackedLocations=true);
    writeJSON(path, getCloneClassInfo(asts), unpackedLocations=true);
}

// Writes clone class data to json
void exportToJson(list[list[node]] cloneClasses, loc path) {
    list[loc] nodeLoc = [];
    for (nodeList <- cloneClasses) {
        for (noddee <- nodeList) {
            try
                nodeLoc += [getLoc(noddee)];
            catch:
                break;
        }
    }
    
    writeJSON(path, nodeLoc, unpackedLocations=true);
}

// Finds a list of clone classes given an AST
list[list[node]] findClones(list[Declaration] ast) {

    map[node, list[node]] subtrees = ();

       visit (ast) {
           case node n:
            {
                node unsetSubtree = unsetRec(n);
                if(getSize(unsetSubtree) > 15) { 
                    if (unsetSubtree in subtrees) {
                        subtrees[unsetSubtree] += [n];
                    }
                    else {
                        list[node] tmpList = [n];
                        subtrees[unsetSubtree] = [n];
                    }
                }
             }
        }

        println("Different node types found:"); 
        println(size(subtrees));
        list[list[node]] cloneClasses = [];

        // GET ACTUAL CLONE CLASSES (>1)
        for (class <- range(subtrees)) {
            if (size(class) > 1) {
                cloneClasses += [class];
            }
        }
        println("Amount of non-1 clone classes found:");
        println(size(cloneClasses));

        return removeSubClones(cloneClasses);;
}

// Returns the loc of a node if it has one
loc getLoc(node n) {
    switch (n.src ) {
        case loc l:
            return l;
        default:
            throw "node has no loc";
    }
    
}

// Given a list of clone classes this function removes all classes from that list that are contained in any of the other classes and returns it
list[list[node]] removeSubClones(list[list[node]] subtrees) {
    list[list[node]] toRemove = [];

    for (smallerClass <- subtrees) {
        for (biggerClass <- subtrees){
            if (isSubsumedIn(smallerClass, biggerClass)) {
                subtrees -= [smallerClass];
            }

        }
    }
    println("Amount of clone classes after subsumption:");
    println(size(subtrees));
    return subtrees;
}

// Given two clone classes this function checks whether one is contained in the other
bool isSubsumedIn(list[node] smallerClass, biggerClass) {
    bool isSubset = true;
    for (cloneA <- smallerClass) {
        bool found = false;
        for (cloneB <- biggerClass) {
            try
                found = isStrictlyContainedIn(getLoc(cloneA), getLoc(cloneB));
            catch:
                ;
            if (found) {
                break;
            }
        } 
        if (!found) {
            isSubset = false;
            break;
        }
    }
    return isSubset;
}

// This function returns the mass of a node
int getSize(node n) {
    int size = 0;
    visit (n) {
        case node n:
            {
                size += 1;
            }
    }
    return size;
}