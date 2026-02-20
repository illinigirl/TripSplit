//
//  TripReportGenerator.swift
//  TripSplitApp
//

import UIKit
import SwiftUI

// Subclassing is required — KVC setValue(forKey:) for paperRect/printableRect
// is unreliable on modern iOS and frequently produces 0 pages.
private class PDFPageRenderer: UIPrintPageRenderer {
    let pageSize: CGSize
    let margin: CGFloat

    init(pageSize: CGSize, margin: CGFloat) {
        self.pageSize = pageSize
        self.margin = margin
    }

    override var paperRect: CGRect {
        CGRect(origin: .zero, size: pageSize)
    }

    override var printableRect: CGRect {
        CGRect(x: margin, y: margin,
               width: pageSize.width - margin * 2,
               height: pageSize.height - margin * 2)
    }
}

struct TripReportGenerator {
    let trip: Trip

    /// Writes the PDF to a temp file and returns the URL, ready for ShareLink.
    func generateReportURL() -> URL {
        let data = generatePDF()
        let safeName = trip.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName) Report.pdf")
        try? data.write(to: url)
        return url
    }

    func generatePDF() -> Data {
        let html = buildHTML()
        let formatter = UIMarkupTextPrintFormatter(markupText: html)

        let pageSize = CGSize(width: 612, height: 792) // US Letter
        let renderer = PDFPageRenderer(pageSize: pageSize, margin: 54)
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageRect = CGRect(origin: .zero, size: pageSize)
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)

        let pageCount = renderer.numberOfPages
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: pageCount))
        for i in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: pageRect)
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    // MARK: - HTML

    private func buildHTML() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium

        let settlements = calculateSettlements()
        let sortedExpenses = trip.expenses.sorted(by: { $0.date < $1.date })

        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
            body { font-family: -apple-system, Helvetica Neue, sans-serif; font-size: 12px; color: #1a1a1a; }
            h1 { color: #1a7fa8; font-size: 22px; margin: 0 0 4px 0; }
            h2 { color: #1a7fa8; font-size: 14px; border-bottom: 1px solid #ddd; padding-bottom: 4px; margin: 24px 0 8px 0; }
            .meta { color: #888; font-size: 11px; margin-bottom: 20px; }
            table { width: 100%; border-collapse: collapse; margin-top: 4px; }
            th { text-align: left; color: #666; font-size: 10px; font-weight: 600; text-transform: uppercase;
                 padding: 5px 8px; background: #f5f5f5; }
            td { padding: 6px 8px; border-bottom: 1px solid #f0f0f0; font-size: 12px; }
            .right { text-align: right; }
            .green { color: #2e7d32; }
            .red { color: #c62828; }
            .expense { margin-top: 10px; border: 1px solid #e8e8e8; border-radius: 4px; page-break-inside: avoid; }
            .expense-header { background: #f8f8f8; padding: 8px 10px; overflow: hidden; }
            .expense-title { font-weight: 600; font-size: 13px; float: left; }
            .expense-amount { font-weight: 700; color: #1a7fa8; font-size: 13px; float: right; }
            .expense-sub { clear: both; color: #888; font-size: 10px; padding-top: 2px; }
            .shares td { padding: 3px 10px; font-size: 11px; border-bottom: 1px solid #f8f8f8; }
        </style>
        </head>
        <body>
        """

        html += "<h1>\(escape(trip.name))</h1>"
        html += "<div class='meta'>Generated \(df.string(from: Date()))"
        html += " &nbsp;·&nbsp; \(sortedExpenses.count) expense\(sortedExpenses.count == 1 ? "" : "s")"
        html += " &nbsp;·&nbsp; \(trip.participants.count) participants</div>"

        // Overview
        html += "<h2>Overview</h2><table>"
        html += "<tr><td>Total Spent</td><td class='right'><strong>$\(fmt(trip.totalSpent))</strong></td></tr>"
        html += "<tr><td>Trip Start</td><td class='right'>\(df.string(from: trip.startDate))</td></tr>"
        if let end = trip.endDate {
            html += "<tr><td>Trip End</td><td class='right'>\(df.string(from: end))</td></tr>"
        }
        html += "</table>"

        // Balances
        html += "<h2>Balances</h2>"
        html += "<table><tr><th>Person</th><th class='right'>Paid</th><th class='right'>Owes</th><th class='right'>Net</th></tr>"
        for person in trip.participants.sorted(by: { $0.netBalance(in: trip) > $1.netBalance(in: trip) }) {
            let net = person.netBalance(in: trip)
            let netDisplay = net >= 0 ? "+$\(fmt(net))" : "-$\(fmt(abs(net)))"
            let netClass = net >= 0 ? "green" : "red"
            html += "<tr>"
            html += "<td>\(escape(person.name))</td>"
            html += "<td class='right'>$\(fmt(person.totalPaid(in: trip)))</td>"
            html += "<td class='right'>$\(fmt(person.totalOwed(in: trip)))</td>"
            html += "<td class='right \(netClass)'>\(netDisplay)</td>"
            html += "</tr>"
        }
        html += "</table>"

        // Expenses
        html += "<h2>Expenses (\(sortedExpenses.count))</h2>"
        for expense in sortedExpenses {
            let payerName = expense.paidBy?.name ?? "Unknown"
            let sortedShares = expense.shares
                .compactMap { share -> (String, Double)? in
                    guard let person = share.person else { return nil }
                    return (person.name, share.amount)
                }
                .sorted(by: { $0.0 < $1.0 })

            html += "<div class='expense'>"
            html += "<div class='expense-header'>"
            html += "<span class='expense-amount'>$\(fmt(expense.amount))</span>"
            html += "<span class='expense-title'>\(escape(expense.expenseDescription))</span>"
            html += "<div class='expense-sub'>\(df.string(from: expense.date))"
            html += " &nbsp;·&nbsp; \(escape(expense.category))"
            html += " &nbsp;·&nbsp; Paid by \(escape(payerName))</div>"
            html += "</div>"

            if !sortedShares.isEmpty {
                html += "<table class='shares'>"
                for (name, amount) in sortedShares {
                    html += "<tr><td>\(escape(name))</td><td class='right'>$\(fmt(amount))</td></tr>"
                }
                html += "</table>"
            }
            html += "</div>"
        }

        // Settlements
        html += "<h2>Suggested Settlements</h2>"
        if settlements.isEmpty {
            html += "<p class='green'><strong>Everyone is settled up — no payments needed.</strong></p>"
        } else {
            html += "<table><tr><th>From</th><th>To</th><th class='right'>Amount</th></tr>"
            for payment in settlements {
                html += "<tr>"
                html += "<td>\(escape(payment.from.name))</td>"
                html += "<td>\(escape(payment.to.name))</td>"
                html += "<td class='right'>$\(fmt(payment.amount))</td>"
                html += "</tr>"
            }
            html += "</table>"
        }

        html += "</body></html>"
        return html
    }

    // MARK: - Helpers

    private func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func calculateSettlements() -> [Payment] {
        var balances = trip.participants.map { ($0, $0.netBalance(in: trip)) }

        for record in trip.paymentRecords {
            if let fromPerson = trip.participants.first(where: { $0.name == record.fromPersonName }),
               let toPerson = trip.participants.first(where: { $0.name == record.toPersonName }) {
                if let i = balances.firstIndex(where: { $0.0 == fromPerson }) { balances[i].1 += record.amount }
                if let i = balances.firstIndex(where: { $0.0 == toPerson }) { balances[i].1 -= record.amount }
            }
        }

        var payments: [Payment] = []
        balances = balances.filter { abs($0.1) > 0.01 }

        while !balances.isEmpty {
            guard let creditorIndex = balances.indices.max(by: { balances[$0].1 < balances[$1].1 }),
                  balances[creditorIndex].1 > 0.01 else { break }
            guard let debtorIndex = balances.indices.min(by: { balances[$0].1 < balances[$1].1 }),
                  balances[debtorIndex].1 < -0.01 else { break }

            let paymentAmount = min(balances[creditorIndex].1, abs(balances[debtorIndex].1))
            payments.append(Payment(from: balances[debtorIndex].0, to: balances[creditorIndex].0, amount: paymentAmount))

            balances[creditorIndex].1 -= paymentAmount
            balances[debtorIndex].1 += paymentAmount
            balances = balances.filter { abs($0.1) > 0.01 }
        }

        return payments
    }
}
