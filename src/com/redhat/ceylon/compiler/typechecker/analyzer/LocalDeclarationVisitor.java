/*
 * Copyright Red Hat Inc. and/or its affiliates and other contributors
 * as indicated by the authors tag. All rights reserved.
 *
 * This copyrighted material is made available to anyone wishing to use,
 * modify, copy, or redistribute it subject to the terms and conditions
 * of the GNU General Public License version 2.
 * 
 * This particular file is subject to the "Classpath" exception as provided in the 
 * LICENSE file that accompanied this code.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT A
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License,
 * along with this distribution; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA  02110-1301, USA.
 */
package com.redhat.ceylon.compiler.typechecker.analyzer;

import java.util.HashMap;
import java.util.Map;

import com.redhat.ceylon.compiler.typechecker.model.ClassOrInterface;
import com.redhat.ceylon.compiler.typechecker.model.Declaration;
import com.redhat.ceylon.compiler.typechecker.model.Method;
import com.redhat.ceylon.compiler.typechecker.model.Value;
import com.redhat.ceylon.compiler.typechecker.tree.NaturalVisitor;
import com.redhat.ceylon.compiler.typechecker.tree.Tree;
import com.redhat.ceylon.compiler.typechecker.tree.Visitor;

public class LocalDeclarationVisitor extends Visitor implements NaturalVisitor {

    private Map<String,Integer> localNames;
    private String prefix;
    
    private void visitLocalDecl(Tree.Declaration that) {
        Declaration model = that.getDeclarationModel();
        visitLocalDeclarationModel(model);
    }

    private void visitLocalDecl(Tree.ObjectArgument that) {
        Declaration model = that.getDeclarationModel();
        visitLocalDeclarationModel(model);
    }

    private void visitLocalDeclarationModel(Declaration model) {
        if(model != null 
                && !model.isToplevel()
                && !model.isMember()
                && !(model instanceof Method && model.isParameter())
                && localNames!=null){
            Integer counter = localNames.get(model.getName());
            if(counter == null)
                counter = 1;
            else
                counter = counter + 1;
            localNames.put(model.getName(), counter);
            String qualifier;
            if(prefix != null)
                qualifier = prefix + counter.toString();
            else
                qualifier = counter.toString();
            model.setQualifier(qualifier);
        }
    }

    @Override
    public void visit(Tree.TypeAliasDeclaration that) {
        // type aliases don't introduce new scopes
        visitLocalDecl(that);
        super.visit(that);
    }

    @Override
    public void visit(Tree.ClassOrInterface that) {
        ClassOrInterface model = that.getDeclarationModel();
        visitLocalDecl(that);

        Map<String,Integer> oldLocalNames = null;
        if(model != null && !model.isAlias()){
            oldLocalNames = localNames;
            localNames = new HashMap<String,Integer>();
        }
        super.visit(that);
        if(model != null && !model.isAlias()){
            localNames = oldLocalNames;
        }
    }
    
    @Override
    public void visit(Tree.ObjectDefinition that) {
        visitLocalDecl(that);
        // use the same qualifier for the object type
        if(that.getAnonymousClass() != null
                && that.getDeclarationModel() != null) {
            that.getAnonymousClass().setQualifier(that.getDeclarationModel().getQualifier());
        }

        Map<String,Integer> oldLocalNames = localNames;
        localNames = new HashMap<String,Integer>();

        super.visit(that);
        
        localNames = oldLocalNames;
    }

    @Override
    public void visit(Tree.ObjectArgument that) {
        visitLocalDecl(that);
        // use the same qualifier for the object type
        if(that.getAnonymousClass() != null
                && that.getDeclarationModel() != null) {
            that.getAnonymousClass().setQualifier(that.getDeclarationModel().getQualifier());
        }

        Map<String,Integer> oldLocalNames = localNames;
        localNames = new HashMap<String,Integer>();

        super.visit(that);
        
        localNames = oldLocalNames;
    }

    @Override
    public void visit(Tree.AnyMethod that) {
        visitLocalDecl(that);

        Map<String,Integer> oldLocalNames = localNames;
        localNames = new HashMap<String,Integer>();

        super.visit(that);
        
        localNames = oldLocalNames;
    }

    @Override
    public void visit(Tree.AttributeGetterDefinition that) {
        visitLocalDecl(that);

        Map<String,Integer> oldLocalNames = localNames;
        localNames = new HashMap<String,Integer>();

        super.visit(that);
        
        localNames = oldLocalNames;
    }

    @Override
    public void visit(Tree.AttributeSetterDefinition that) {
        // setters use the same prefix as the getter with a $setter$ prefix
        
        Map<String,Integer> oldLocalNames = localNames;
        localNames = new HashMap<String,Integer>();

        super.visit(that);
        
        localNames = oldLocalNames;
    }

    @Override
    public void visit(Tree.AttributeDeclaration that) {
        Value model = that.getDeclarationModel();
        if(model != null && model.isToplevel()){
            Map<String,Integer> oldLocalNames = localNames;
            String oldPrefix = prefix;
            localNames = new HashMap<String,Integer>();
            prefix = "1"+model.getName()+"$";

            super.visit(that);
        
            localNames = oldLocalNames;
            prefix = oldPrefix;
        }else{
            super.visit(that);
        }
    }
}