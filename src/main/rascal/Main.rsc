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

int main(int testArgument=0) {
    println("argument: <testArgument>");

    loc testJavaProject = |cwd://javaTestProject|;
    list[Declaration]  asts = getASTs(testJavaProject);

    for (ast <- asts) {
        findClones(asts);
    } 
    return testArgument;
}


list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}



void findClones(list[Declaration] ast) {

    map[node, list[node]] subtrees = ();

  //  map[loc, int] subtreeSizes = (); // Store subtree sizes for reuse

       visit (ast) {
           case node n:
             {
                node unsetSubtree = unsetRec(n);
              //  println(unsetSubtree);
              // TODO check if subtree is above treshhold otherwise you just get ints etc -> in report: do quick analysis of this threshold and explain why I dont care about a too small numder
                if(arity(unsetSubtree) > 1) { // play around with this to get granularity of clones
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
        int c = 0;
        println(toJSON(subtrees));
        writeJSON(|file:///home/jan/Nextcloud/uni/SEvolution/series2-Jan/src/testJsonExport.json|, subtrees, bool unpackedLocations=true);







        println("Amount of clone classes");
        println(size(subtrees)); // struggling with range because it returns a set. goal is = lsit of lists of clones
        list[node] emptyList = [];
        list[list[node]] cloneClasses = [emptyList];
        for (class <- subtrees) {
            if (size(class) > 1) {
                println(class);
                cloneClasses += [class];
                println("Clone class with size:");
                println(size(class));
                for (clone <- class) {
                    try
                        println(getLoc(clone));
                    catch:
                     break;
                }
            }
        }
        // println("size");
        // println(size(subtrees));
        // println("range");
        // println(range(subtrees));
        // println("domain");
        // println(domain(subtrees));
        // println("domain.size");
        // println(size(domain(subtrees)));
        println("Amount of non-1 clone classes");
        println(size(subtrees));
         subtrees = removeSubClones(cloneClasses);
}

loc getLoc(node n) {
    switch (n.src ) {
        case loc l:
            return l;
        default:
            throw "node has no loc";
    }
    
}

map[node, list[node]] removeSubClones(map[node, list[node]] subtrees) {
    // implement removal of subtrees here
    map[node, list[node]] cleanedSubtrees = ();
    bool keepTrying = true;


    for (cloneclassA <- range(subtrees)) {
        keepTrying = true;
        if (size(cloneclassA) <= 1) {
            continue;
        }
        for (cloneClassB <- range(subtrees)){
            keepTrying = true; // continue here playing around with this
            if (size(cloneClassB) > 1) {
                for (cloneA <- cloneclassA) {
                    if (!keepTrying) {
                            break;
                        }
                    for (cloneB <- cloneClassB) {
                        if (!keepTrying) {
                            break;
                        }
                        bool found = false;
                        try
                            found = isStrictlyContainedIn(getLoc(cloneA), getLoc(cloneB));
                        catch:
                            int x; // do do smt here
                        if (found) {
                            keepTrying = true;
                            println("found a subclone set");
                            println(getLoc(cloneA));
                            println(getLoc(cloneB));
                        }
                        else {
                            keepTrying = false;
                        }
                    }   // continue here
            }
        }      
    }
    }
    return cleanedSubtrees;
}

    //domain -> keys
    // range -> values 
    // isstrictlycontained in 
    // if every node in one class of the 

    // is hij in een van de vijf er in passend? 
  //   elke van a moet contained in een van de b zijn 

  


            //     int size = 1;
            //     println("I am node type: ");
            //     println(getName(n));
            //     println("My children are:");
            //     list[node] children = [child | node child <- getChildren(n)];
            //     list[list[node]] listChildren = [child | list[node]]
            //     for (child <- children ) {
            //         println(getName(child));
            //         //if (child.src ?) size += subtreeSizes[child.src];

            //     }
            //     //subtreeSizes[n.src] = size;


            //     // println(arity(n));
            //     // // only hash for non-leaves
            //     // if (arity(n) != 0 && arity(n) > 5 ) {
                    
            //     //     if (n.typ ?) println(n.typ);
            //     //     //myhash= hash(n.typ);
            //     //     //runninghash = runninghash + myhash;
            //    // }